module github.com/cloudfoundry/bosh-windows-stemcell-builder/stembuild

go 1.23.0

require (
	github.com/concourse/pool-resource v1.1.1
	github.com/golang/mock v1.6.0
	github.com/google/subcommands v1.2.0
	github.com/google/uuid v1.6.0
	github.com/masterzen/winrm v0.0.0-20240702205601-3fad6e106085
	github.com/maxbrunsfeld/counterfeiter/v6 v6.11.2
	github.com/onsi/ginkgo/v2 v2.23.4
	github.com/onsi/gomega v1.37.0
	github.com/packer-community/winrmcp v0.0.0-20221126162354-6e900dd2c68f
	github.com/pkg/errors v0.9.1
	github.com/vmware/govmomi v0.50.0
	golang.org/x/sys v0.33.0
)

require (
	github.com/Azure/go-ntlmssp v0.0.0-20221128193559-754e69321358 // indirect
	github.com/ChrisTrenkamp/goxpath v0.0.0-20210404020558-97928f7e12b6 // indirect
	github.com/a8m/tree v0.0.0-20240104212747-2c8764a5f17e // indirect
	github.com/bodgit/ntlmssp v0.0.0-20240506230425-31973bb52d9b // indirect
	github.com/bodgit/windows v1.0.1 // indirect
	github.com/dougm/pretty v0.0.0-20171025230240-2ee9d7453c02 // indirect
	github.com/dylanmei/iso8601 v0.1.0 // indirect
	github.com/go-logr/logr v1.4.2 // indirect
	github.com/go-task/slim-sprig/v3 v3.0.0 // indirect
	github.com/gofrs/uuid v4.4.0+incompatible // indirect
	github.com/google/go-cmp v0.7.0 // indirect
	github.com/google/pprof v0.0.0-20250501235452-c0086092b71a // indirect
	github.com/hashicorp/go-cleanhttp v0.5.2 // indirect
	github.com/hashicorp/go-uuid v1.0.3 // indirect
	github.com/jcmturner/aescts/v2 v2.0.0 // indirect
	github.com/jcmturner/dnsutils/v2 v2.0.0 // indirect
	github.com/jcmturner/gofork v1.7.6 // indirect
	github.com/jcmturner/goidentity/v6 v6.0.1 // indirect
	github.com/jcmturner/gokrb5/v8 v8.4.4 // indirect
	github.com/jcmturner/rpc/v2 v2.0.3 // indirect
	github.com/kr/text v0.2.0 // indirect
	github.com/masterzen/simplexml v0.0.0-20190410153822-31eea3082786 // indirect
	github.com/mitchellh/mapstructure v1.3.0 // indirect
	github.com/nu7hatch/gouuid v0.0.0-20131221200532-179d4d0c4d8d // indirect
	github.com/onsi/ginkgo v1.16.5 // indirect
	github.com/rogpeppe/go-internal v1.14.1 // indirect
	github.com/tidwall/transform v0.0.0-20201103190739-32f242e2dbde // indirect
	go.uber.org/automaxprocs v1.6.0 // indirect
	golang.org/x/crypto v0.38.0 // indirect
	golang.org/x/mod v0.24.0 // indirect
	golang.org/x/net v0.40.0 // indirect
	golang.org/x/sync v0.14.0 // indirect
	golang.org/x/text v0.25.0 // indirect
	golang.org/x/tools v0.33.0 // indirect
	google.golang.org/protobuf v1.36.5 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace github.com/masterzen/winrm => github.com/bosh-dep-forks/winrm v0.0.0-20240321234108-df0e10ca9199

replace github.com/packer-community/winrmcp => github.com/bosh-dep-forks/winrmcp v0.0.0-20240506194308-1105f7feefc7
