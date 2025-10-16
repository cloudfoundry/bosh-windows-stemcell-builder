GOSRC = $(shell find . -name "*.go" ! -name "*test.go" ! -name "*fake*" ! -path "./integration/*")
STEMCELL_VERSION = $(shell echo "$${STEMBUILD_VERSION}")
LD_FLAGS = "-w -s -X github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild/version.Current=${STEMCELL_VERSION}"

ifeq ($(OS),Windows_NT)
	COMMAND = out/stembuild.exe
	CP = cp
else
	UNAME = $(shell uname -s)
	COMMAND = out/stembuild

	ifeq ($(UNAME),Darwin)
		CP = cp -p
	else ifeq ($(UNAME),Linux)
		CP = cp --preserve=mode,ownership
	endif
endif

assets/StemcellAutomation.zip:
	@echo "Unable to locate assets/StemcellAutomation.zip. This file is bundled into the final stembuild executable and must be present. Please see README.md on how to construct this file."
	exit 1

all : stembuild stembuild.exe
stembuild : out/stembuild
stembuild.exe : out/stembuild.exe

out/stembuild : assets $(GOSRC)
	CGO_ENABLED=0 go build -o $(COMMAND) -ldflags $(LD_FLAGS) .

out/stembuild.exe : assets $(GOSRC)
	GOOS=windows CGO_ENABLED=0 go build -o out/stembuild.exe -ldflags $(LD_FLAGS) .

clean :
	rm -rf assets/StemcellAutomation.zip out/*

units : stubbed-stemcell-automation-zip
	go run github.com/onsi/ginkgo/v2/ginkgo run -r --randomize-all --randomize-suites --keep-going --skip-package integration

integration : stubbed-stemcell-automation-zip
	go run github.com/onsi/ginkgo/v2/ginkgo run -r --timeout 3h -vv --randomize-all --keep-going --flake-attempts 2 integration

integration-build : stubbed-stemcell-automation-zip $(GOSRC)
	go build -o $(COMMAND) -ldflags $(LD_FLAGS) .

stubbed-stemcell-automation-zip :
	$(CP) integration/construct/assets/StemcellAutomation.zip assets/


.PHONY : all stembuild stembuild.exe clean
.PHONY : units iaas_cli integration integration-build stubbed-stemcell-automation-zip
