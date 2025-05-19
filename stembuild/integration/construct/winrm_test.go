package construct_test

import (
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

	AfterEach(func() {
		_, err := rm.ExecuteCommand("powershell.exe Remove-Item c:\\provision -recurse")
		Expect(err).ToNot(HaveOccurred())
	})

	Context("ExtractArchive", func() {
		BeforeEach(func() {
			err := rm.UploadArtifact(filepath.Join("assets", "StemcellAutomation.zip"), "C:\\provision\\StemcellAutomation.zip")
			Expect(err).ToNot(HaveOccurred())
		})

		It("succeeds when Extract-Archive powershell function returns zero exit code", func() {
			err := rm.ExtractArchive("C:\\provision\\StemcellAutomation.zip", "C:\\provision")
			Expect(err).ToNot(HaveOccurred())
		})

		It("fails when Extract-Archive powershell function returns non-zero exit code", func() {
			err := rm.ExtractArchive("C:\\provision\\NonExistingFile.zip", "C:\\provision")
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
