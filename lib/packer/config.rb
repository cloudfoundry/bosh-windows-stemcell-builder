module Packer
  module Config
    class Base
      def scripts_dir

      end

      def builders
        []
      end

      def provisioners
        {
          "agent_zip" => {
            "type" => "file",
            "source" => "../../compiled-agent/agent.zip",
            "destination" => "C:\\bosh\\agent.zip"
          },
          "agent_deps_zip" => {
            "type" => "file",
            "source" => "../../compiled-agent/agent-dependencies.zip",
            "destination" => "C:\\bosh\\agent-dependencies.zip"
          },
          "final_powershell" => {
            "type" => "powershell",
            "scripts" => [
              "../scripts/add-windows-features.ps1",
              "../scripts/run-policies.ps1",
              "../scripts/setup_agent.ps1",
              "scripts/agent_config.ps1",
              "../scripts/cleanup-windows-features.ps1",
              "../scripts/disable-services.ps1",
              "../scripts/set-firewall.ps1",
              "../scripts/cleanup-artifacts.ps1"
            ]
          }
        }
      end

      def dump

      end
    end

    class Aws < Base
      def builders

      end

      def provisioners
        foo = super
        puts foo
      end
    end

    class Gcp < Base

    end

    class VSphere < Base

    end

    class Azure < Base

    end

    class OpenStack < Base

    end
  end
end

