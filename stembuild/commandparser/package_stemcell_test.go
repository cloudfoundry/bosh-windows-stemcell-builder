package commandparser_test

import (
	"context"
	"errors"
	"flag"
	"fmt"

	"github.com/google/subcommands"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	. "github.com/onsi/gomega/gbytes"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/colorlogger"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/commandparser/commandparserfakes"
	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/messenger"
)

var _ = Describe("package_stemcell", func() {
	// Focus of this test is not to test the Flags.Parse functionality as much
	// as to test that the command line flags values are stored in the expected
	// struct variables. This adds a bit of protection when renaming flag parameters.
	Describe("SetFlags", func() {

		var (
			f          *flag.FlagSet
			packageCmd *commandparser.PackageCmd

			outBuf *Buffer
			errBuf *Buffer

			oSAndVersionGetter *commandparserfakes.FakeOSAndVersionGetter
			packagerFactory    *commandparserfakes.FakePackagerFactory
			packager           *commandparserfakes.FakePackager
		)

		BeforeEach(func() {
			f = flag.NewFlagSet("test", flag.ContinueOnError)

			outBuf = NewBuffer()
			errBuf = NewBuffer()

			packager = new(commandparserfakes.FakePackager)

			oSAndVersionGetter = new(commandparserfakes.FakeOSAndVersionGetter)
			packagerFactory = new(commandparserfakes.FakePackagerFactory)
			packagerFactory.NewPackagerReturns(packager, nil)
			logger := colorlogger.New(0, false, GinkgoWriter)
			stembuildMessenger := messenger.NewStembuildMessenger(outBuf, errBuf)

			packageCmd = commandparser.NewPackageCommand(oSAndVersionGetter, packagerFactory, logger, stembuildMessenger)
			packageCmd.SetFlags(f)
			packageCmd.GlobalFlags = &commandparser.GlobalFlags{}
		})

		var defaultArgs []string

		Describe("Execute", func() {
			BeforeEach(func() {
				oSAndVersionGetter.GetVersionReturns("2019.2")
				oSAndVersionGetter.GetOsReturns("2019")
			})

			It("packager is instantiated with expected vmdk source config", func() {
				vmdkArgs := []string{"-vmdk", "some_vmdk_file"}

				err := f.Parse(vmdkArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitSuccess))

				Expect(packagerFactory.NewPackagerCallCount()).To(Equal(1))
				actualSourceConfig, _, _, _ := packagerFactory.NewPackagerArgsForCall(0)
				Expect(actualSourceConfig.Vmdk).To(Equal("some_vmdk_file"))
			})

			It("packager is instantiated with expected vcenter source config", func() {
				vcenterArgs := []string{
					"-vcenter-url", "https://vcenter.test",
					"-vcenter-username", "test-user",
					"-vcenter-password", "verysecure",
					"-vcenter-ca-certs", "/path/to/cert/file",
					"-vm-inventory-path", "/path/to/vm",
				}

				err := f.Parse(vcenterArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitSuccess))

				Expect(packagerFactory.NewPackagerCallCount()).To(Equal(1))
				actualSourceConfig, _, _, _ := packagerFactory.NewPackagerArgsForCall(0)
				Expect(actualSourceConfig.URL).To(Equal("https://vcenter.test"))
				Expect(actualSourceConfig.Username).To(Equal("test-user"))
				Expect(actualSourceConfig.Password).To(Equal("verysecure"))
				Expect(actualSourceConfig.VmInventoryPath).To(Equal("/path/to/vm"))
				Expect(actualSourceConfig.CaCertFile).To(Equal("/path/to/cert/file"))
			})

			It("packager is instantiated with expected output config directory when using long form -outputdir", func() {
				longformOutputDirArgs := []string{"-outputDir", "some_output_dir"}

				err := f.Parse(longformOutputDirArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitSuccess))

				Expect(packagerFactory.NewPackagerCallCount()).To(Equal(1))
				_, actualOutputConfig, _, _ := packagerFactory.NewPackagerArgsForCall(0)
				Expect(actualOutputConfig.OutputDir).To(Equal("some_output_dir"))
			})

			It("packager is instantiated with expected output config when using short form -o", func() {
				shortformOutputDirArgs := []string{"-o", "some_output_dir"}

				err := f.Parse(shortformOutputDirArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitSuccess))

				Expect(packagerFactory.NewPackagerCallCount()).To(Equal(1))
				_, actualOutputConfig, _, _ := packagerFactory.NewPackagerArgsForCall(0)
				Expect(actualOutputConfig.OutputDir).To(Equal("some_output_dir"))
				Expect(actualOutputConfig.StemcellVersion).To(Equal("2019.2"))
				Expect(actualOutputConfig.Os).To(Equal("2019"))
			})

			It("creates packager with correct stemcell patch version number when argument provided", func() {
				oSAndVersionGetter.GetVersionWithPatchNumberReturns("1803.27.36")

				args := append(defaultArgs, "-patch-version", "36")

				err := f.Parse(args)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitSuccess))

				Expect(packagerFactory.NewPackagerCallCount()).To(Equal(1))
				_, actualOutputConfig, _, _ := packagerFactory.NewPackagerArgsForCall(0)
				Expect(actualOutputConfig.StemcellVersion).To(Equal("1803.27.36"))

				Expect(oSAndVersionGetter.GetVersionWithPatchNumberCallCount()).To(Equal(1))
				actualPatchVersion := oSAndVersionGetter.GetVersionWithPatchNumberArgsForCall(0)
				Expect(actualPatchVersion).To(Equal("36"))
			})

			It("package is not called if the OS is invalid", func() {
				getOsReturnValue := "2017"
				oSAndVersionGetter.GetOsReturns(getOsReturnValue)

				err := f.Parse(defaultArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitFailure))

				Expect(packager.PackageCallCount()).To(Equal(0))

				expectedMessage := fmt.Sprintf("versioning error; parsed os version is: %s", getOsReturnValue)
				Eventually(errBuf).Should(Say(expectedMessage))
			})

			It("package is not called if the packager factory returns an error", func() {
				newPackagerErr := errors.New("fake-new-packager-error")
				packagerFactory.NewPackagerReturns(nil, newPackagerErr)

				err := f.Parse(defaultArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitFailure))

				Expect(packagerFactory.NewPackagerCallCount()).To(Equal(1))
				Expect(packager.PackageCallCount()).To(Equal(0))

				Eventually(errBuf).Should(Say(newPackagerErr.Error()))
			})

			It("package is not called if there is no free space", func() {
				validateFreeSpaceErr := errors.New("fake-validate-free-space-error")
				packager.ValidateFreeSpaceForPackageReturns(validateFreeSpaceErr)

				err := f.Parse(defaultArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitFailure))

				Expect(packager.ValidateFreeSpaceForPackageCallCount()).To(Equal(1))
				Expect(packager.PackageCallCount()).To(Equal(0))

				Eventually(errBuf).Should(Say(validateFreeSpaceErr.Error()))
			})

			It("package is not called if source parameters are not valid", func() {
				validateSourceParamsErr := errors.New("fake-invalid-source-params-error")
				packager.ValidateSourceParametersReturns(validateSourceParamsErr)

				err := f.Parse(defaultArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitFailure))

				Expect(packager.ValidateSourceParametersCallCount()).To(Equal(1))
				Expect(packager.PackageCallCount()).To(Equal(0))

				Eventually(errBuf).Should(Say(validateSourceParamsErr.Error()))
			})

			It("exits with failure if package returns an error", func() {
				packageErr := errors.New("fake-package-error")
				packager.PackageReturns(packageErr)

				err := f.Parse(defaultArgs)
				Expect(err).ToNot(HaveOccurred())

				exitStatus := packageCmd.Execute(context.Background(), f)
				Expect(exitStatus).To(Equal(subcommands.ExitFailure))

				Expect(packager.PackageCallCount()).To(Equal(1))

				Eventually(errBuf).Should(Say(packageErr.Error()))
			})
		})
	})
})
