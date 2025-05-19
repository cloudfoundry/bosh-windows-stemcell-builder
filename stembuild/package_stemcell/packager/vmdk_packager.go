package packager

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/sha1"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"time"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/filesystem"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/config"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/package_stemcell/ovftool"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/templates"
)

const Gigabyte = 1024 * 1024 * 1024

type VmdkPackager struct {
	Image        string
	Stemcell     string
	Manifest     string
	Sha1sum      string
	tmpdir       string
	Stop         chan struct{}
	BuildOptions config.VmdkOptions
	Logger       colorlogger.Logger
}

var ErrInterrupt = errors.New("interrupt")

type CancelWriter struct {
	w    io.Writer
	stop chan struct{}
}

func (w *CancelWriter) Write(p []byte) (int, error) {
	select {
	case <-w.stop:
		return 0, ErrInterrupt
	default:
		return w.w.Write(p)
	}
}

type CancelReader struct {
	r    io.Reader
	stop chan struct{}
}

func (r *CancelReader) Read(p []byte) (int, error) {
	select {
	case <-r.stop:
		return 0, ErrInterrupt
	default:
		return r.r.Read(p)
	}
}

// returns a io.Writer that returns an error when VmdkPackager c is stopped
func (c *VmdkPackager) Writer(w io.Writer) *CancelWriter {
	return &CancelWriter{w: w, stop: c.Stop}
}

// returns a io.Reader that returns an error when VmdkPackager c is stopped
func (c *VmdkPackager) Reader(r io.Reader) *CancelReader {
	return &CancelReader{r: r, stop: c.Stop}
}

func (c *VmdkPackager) StopConfig() {
	c.Logger.Printf("stopping config")
	defer c.Cleanup() // make sure this runs!
	close(c.Stop)
}

func (c *VmdkPackager) Cleanup() {
	if c.tmpdir == "" {
		return
	}
	// check if directory exists to make Cleanup idempotent
	if _, err := os.Stat(c.tmpdir); err == nil {
		c.Logger.Printf("deleting temp directory: %s", c.tmpdir)
		os.RemoveAll(c.tmpdir) //nolint:errcheck
	}
}

func (c *VmdkPackager) AddTarFile(tr *tar.Writer, name string) error {
	c.Logger.Printf("adding file (%s) to tar archive", name)
	f, err := os.Open(name)
	if err != nil {
		return err
	}
	defer f.Close() //nolint:errcheck
	fi, err := f.Stat()
	if err != nil {
		return err
	}
	hdr, err := tar.FileInfoHeader(fi, "")
	if err != nil {
		return err
	}
	if err := tr.WriteHeader(hdr); err != nil {
		return err
	}
	if _, err := io.Copy(tr, c.Reader(f)); err != nil {
		return err
	}
	return nil
}

func (c *VmdkPackager) TempDir() (string, error) {
	if c.tmpdir != "" {
		if _, err := os.Stat(c.tmpdir); err != nil {
			c.Logger.Printf("unable to stat temp dir (%s) was it deleted?", c.tmpdir)
			return "", fmt.Errorf("opening temp directory: %s", c.tmpdir)
		}
		return c.tmpdir, nil
	}
	name, err := os.MkdirTemp(c.BuildOptions.OutputDir, "stemcell-")
	if err != nil {
		return "", fmt.Errorf("creating temp directory: %s", err)
	}
	c.tmpdir = name
	c.Logger.Printf("created temp directory: %s", name)
	return c.tmpdir, nil
}

func (c *VmdkPackager) CreateStemcell() error {
	c.Logger.Printf("creating stemcell")

	// programming errors - panic!
	if c.Manifest == "" {
		panic("CreateStemcell: empty manifest")
	}
	if c.Image == "" {
		panic("CreateStemcell: empty image")
	}

	tmpdir, err := c.TempDir()
	if err != nil {
		return err
	}

	c.Stemcell = filepath.Join(tmpdir, StemcellFilename(c.BuildOptions.Version, c.BuildOptions.OSVersion))
	stemcell, err := os.OpenFile(c.Stemcell, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer stemcell.Close() //nolint:errcheck
	c.Logger.Printf("created temp stemcell: %s", c.Stemcell)

	errorf := func(format string, a ...interface{}) error {
		stemcell.Close()      //nolint:errcheck
		os.Remove(c.Stemcell) //nolint:errcheck
		return fmt.Errorf(format, a...)
	}

	t := time.Now()
	w := gzip.NewWriter(c.Writer(stemcell))
	tr := tar.NewWriter(w)

	c.Logger.Printf("adding image file to stemcell tarball: %s", c.Image)
	if err := c.AddTarFile(tr, c.Image); err != nil {
		return errorf("creating stemcell: %s", err)
	}

	c.Logger.Printf("adding manifest file to stemcell tarball: %s", c.Manifest)
	if err := c.AddTarFile(tr, c.Manifest); err != nil {
		return errorf("creating stemcell: %s", err)
	}

	if err := tr.Close(); err != nil {
		return errorf("creating stemcell: %s", err)
	}

	if err := w.Close(); err != nil {
		return errorf("creating stemcell: %s", err)
	}

	c.Logger.Printf("created stemcell in: %s", time.Since(t))

	return nil
}

func (c *VmdkPackager) ConvertVMX2OVA(vmx, ova string) error {
	const errFmt = "converting vmx to ova: %s\n" +
		"-- BEGIN STDERR OUTPUT -- :\n%s\n-- END STDERR OUTPUT --\n"

	searchPaths, err := ovftool.SearchPaths()
	if err != nil {
		return err
	}
	ovfpath, err := ovftool.Ovftool(searchPaths)
	if err != nil {
		return err
	}

	// ignore stdout
	var stderr bytes.Buffer

	cmd := exec.Command(ovfpath, vmx, ova)
	cmd.Stderr = &stderr

	err = cmd.Start()
	if err != nil {
		return fmt.Errorf("ovftool: %s", err)
	}
	c.Logger.Printf("converting vmx to ova with cmd: %s %s", cmd.Path, cmd.Args[1:])

	// Wait for process exit or interrupt
	errCh := make(chan error, 1)
	go func() { errCh <- cmd.Wait() }()

	select {
	case <-c.Stop:
		if cmd.Process != nil {
			c.Logger.Printf("received stop signall killing ovftool process")
			cmd.Process.Kill() //nolint:errcheck
		}
		return ErrInterrupt
	case chanErr := <-errCh:
		if chanErr != nil {
			return fmt.Errorf(errFmt, chanErr, stderr.String()) //nolint:staticcheck
		}
	}

	return nil
}

// CreateImage converts a vmdk to a gzip compressed image file and records the
// sha1 sum of the resulting image.
func (c *VmdkPackager) CreateImage() error {
	c.Logger.Printf("Creating [image] from [vmdk]: %s", c.BuildOptions.VMDKFile)

	tmpdir, err := c.TempDir()
	if err != nil {
		return err
	}

	var hwVersion int
	switch c.BuildOptions.OSVersion {
	case "2012R2":
		hwVersion = 9
	case "2016", "1803", "2019":
		hwVersion = 10
	}

	vmxPath := filepath.Join(tmpdir, "image.vmx")
	vmdkPath, err := filepath.Abs(c.BuildOptions.VMDKFile)
	if err != nil {
		return err
	}
	if err := templates.WriteVMXTemplate(vmdkPath, hwVersion, vmxPath); err != nil {
		return err
	}

	ovaPath := filepath.Join(tmpdir, "image.ova")
	if err := c.ConvertVMX2OVA(vmxPath, ovaPath); err != nil {
		return err
	}

	// reader
	r, err := os.Open(ovaPath)
	if err != nil {
		return err
	}
	defer r.Close() //nolint:errcheck

	// image file (writer)
	c.Image = filepath.Join(tmpdir, "image")
	f, err := os.OpenFile(c.Image, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer f.Close() //nolint:errcheck

	// calculate sha1 while writing image file
	h := sha1.New()
	w := gzip.NewWriter(io.MultiWriter(f, h))

	if _, err := io.Copy(w, r); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}

	c.Sha1sum = fmt.Sprintf("%x", h.Sum(nil))
	c.Logger.Printf("Sha1 of image (%s): %s", c.Image, c.Sha1sum)
	return nil
}

func (c *VmdkPackager) ConvertVMDK() (string, error) {
	if err := c.CreateImage(); err != nil {
		return "", err
	}
	_, err := c.TempDir()

	if err != nil {
		return "", err
	}
	manifest := CreateManifest(c.BuildOptions.OSVersion, c.BuildOptions.Version, c.Sha1sum)
	if err := WriteManifest(manifest, c.tmpdir); err != nil {
		return "", err
	}
	c.Manifest = filepath.Join(c.tmpdir, "stemcell.MF")

	if err := c.CreateStemcell(); err != nil {
		return "", err
	}

	stemcellPath := filepath.Join(c.BuildOptions.OutputDir, filepath.Base(c.Stemcell))
	c.Logger.Printf("moving stemcell (%s) to: %s", c.Stemcell, stemcellPath)

	if err := os.Rename(c.Stemcell, stemcellPath); err != nil {
		return "", err
	}
	return stemcellPath, nil
}

func (c *VmdkPackager) catchInterruptSignal() {
	ch := make(chan os.Signal, 64)
	signal.Notify(ch, os.Interrupt)
	stopping := false
	for sig := range ch {
		c.Logger.Printf("received signal: %s", sig)
		if stopping {
			fmt.Fprintf(os.Stderr, "received second (%s) signal - exiting now\n", sig) //nolint:errcheck
			c.Cleanup()                                                                // remove temp dir
			os.Exit(1)
		}
		stopping = true
		fmt.Fprintf(os.Stderr, "received (%s) signal cleaning up\n", sig) //nolint:errcheck
		c.StopConfig()
	}
}

func (c *VmdkPackager) Package() error {

	go c.catchInterruptSignal()

	start := time.Now()

	stemcellPath, err := c.ConvertVMDK()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %s\n", err) //nolint:errcheck
		c.Cleanup()                                // remove temp dir
		return err
	}

	c.Logger.Printf("created stemcell (%s) in: %s", stemcellPath, time.Since(start))
	fmt.Printf("created stemcell: %s", stemcellPath)

	c.Cleanup()
	return nil
}

func (c *VmdkPackager) ValidateSourceParameters() error {
	if validVMDK, err := IsValidVMDK(c.BuildOptions.VMDKFile); err != nil {
		return err
	} else if !validVMDK {
		return errors.New("invalid VMDK file")
	}

	searchPaths, err := ovftool.SearchPaths()
	if err != nil {
		return fmt.Errorf("could not get search paths for Ovftool: %s", err)
	}
	_, err = ovftool.Ovftool(searchPaths)
	if err != nil {
		return fmt.Errorf("could not locate Ovftool on PATH: %s", err)
	}
	return nil
}

func IsValidVMDK(vmdk string) (bool, error) {
	fi, err := os.Stat(vmdk)
	if err != nil {
		return false, err
	}
	if !fi.Mode().IsRegular() {
		return false, nil
	}
	return true, nil
}

func (c *VmdkPackager) ValidateFreeSpaceForPackage(fs filesystem.FileSystem) error {
	fi, err := os.Stat(c.BuildOptions.VMDKFile)
	if err != nil {
		return fmt.Errorf("could not get vmdk info: %s", err)
	}
	vmdkSize := fi.Size()

	// make sure there is enough space for ova + stemcell and some leftover
	//	ova and stemcell will be the size of the vmdk in the worst case scenario

	minSpace := uint64(vmdkSize)*2 + (Gigabyte / 2)

	enoughSpace, requiredSpace, err := hasAtLeastFreeDiskSpace(minSpace, fs, filepath.Dir(c.BuildOptions.VMDKFile))
	if err != nil {
		return fmt.Errorf("could not check free space on disk: %s", err)
	}

	if !enoughSpace {
		return fmt.Errorf("Not enough space to create stemcell. Free up %d MB and try again", requiredSpace/(1024*1024)) //nolint:staticcheck
	}
	return nil
}

func hasAtLeastFreeDiskSpace(minFreeSpace uint64, fs filesystem.FileSystem, path string) (bool, uint64, error) {
	freeSpace, err := fs.GetAvailableDiskSpace(path)

	if err != nil {
		return false, 0, err
	}
	return freeSpace >= minFreeSpace, minFreeSpace - freeSpace, nil
}
