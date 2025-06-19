package construct_test

import (
	"fmt"
	"path/filepath"

	"github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/remotemanager"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("WinRM Remote Manager", func() {
	var rm remotemanager.RemoteManager

	BeforeEach(func() {
		clientFactory := remotemanager.NewWinRmClientFactory(conf.TargetIP, conf.VMUsername, conf.VMPassword)
		rm = remotemanager.NewWinRM(conf.TargetIP, conf.VMUsername, conf.VMPassword, clientFactory)
		Expect(rm).ToNot(BeNil())
	})

	Context("ExtractArchive", func() {
		var destPath string

		BeforeEach(func() {
			destPath = "C:\\provision"
			err := rm.UploadArtifact(
				filepath.Join("assets", "StemcellAutomation.zip"),
				fmt.Sprintf("%s\\StemcellAutomation.zip", destPath),
			)
			Expect(err).ToNot(HaveOccurred())
		})

		AfterEach(func() {
			_, err := rm.ExecuteCommand(fmt.Sprintf("powershell.exe Remove-Item %s -recurse", destPath))
			Expect(err).ToNot(HaveOccurred())
		})

		It("succeeds when Extract-Archive powershell function returns zero exit code", func() {
			err := rm.ExtractArchive(fmt.Sprintf("%s\\StemcellAutomation.zip", destPath), destPath)
			Expect(err).ToNot(HaveOccurred())
		})

		It("fails when Extract-Archive powershell function returns non-zero exit code", func() {
			err := rm.ExtractArchive(fmt.Sprintf("%s\\NonExistingFile.zip", destPath), destPath)
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("powershell encountered an issue: "))
		})
	})

	Context("ExecuteCommand", func() {
		It("succeeds when powershell command returns a zero exit code", func() {
			_, err := rm.ExecuteCommand("powershell.exe \"ls c:\\windows 1>$null\"")
			Expect(err).ToNot(HaveOccurred())
		})

		It("fails when powershell command returns non-zero exit code", func() {
			_, err := rm.ExecuteCommand("powershell.exe notRealCommand")
			Expect(err).To(HaveOccurred())
			Expect(err.Error()).To(ContainSubstring("powershell encountered an issue: "))
		})
	})
})
