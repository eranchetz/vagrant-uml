require "vagrant/util/subprocess"
require "vagrant-uml/process"

module VagrantPlugins
  module UML
    class CLI
      attr_accessor :name

      def initialize(name = nil)
        @name = name
        @tunctl_path = Vagrant::Util::Which.which("tunctl")
        @mconsole_path = Vagrant::Util::Which.which("uml_mconsole")
        @switch_path = Vagrant::Util::Which.which("uml_switch")
        @logger = Log4r::Logger.new("vagrant::uml::cli")
      end

      def state(id)
        if !@name
          return :unknown
        else
          begin
            res = Vagrant::Util::Subprocess.execute(@mconsole_path, id, "version", retryable: true)
            if res.stdout =~ /^OK/
              @logger.debug( "Cli.state: instance is running")
              return :running
            else
              return :poweroff
            end
          rescue
            ## We should try to figure out if the machine is stopped, not_created, ...
            #   test if the cow file exists ?
            @logger.debug( "Cli.state: RESCUE instance state unknown error during call to uml_mconsole")
            return :unknown
          end
        end
      end


      def run_uml(*command)
        options = command.last.is_a?(Hash) ? command.pop : {}
        command = command.dup

        #res = Vagrant::Util::Subprocess.execute("tunctl", "-t", options[:machine_id], retryable: true)
        #res2 = Vagrant::Util::Subprocess.execute("ifconfig", options[:machine_id], "192.168.1.254" , "up", retryable: true)

        # umdir should probably be set to data_dir to prevent zombies sockets 
        process = Process.new(
          command[0],
          "ubda=cow,#{options[:rootfs]}" ,
          "umid=#{options[:machine_id]}" ,
          "mem=#{options[:mem]}m" ,
          "eth0=#{options[:eth0]}" ,
          "con0=#{options[:con0]}",
          "con1=#{options[:con1]}",
          "ncpus=#{options[:ncpus]}",
          "con=#{options[:con]}",
          "ssl=#{options[:ssl]}",
          :detach => true ,
          :workdir => options[:data_dir]
        )
        process.run 
      end

      def create_switched_net(options)
      end

      def create_standalone_net(options)
         res = Vagrant::Util::Subprocess.execute(@tunctl_path, "-t", options[:name], retryable: true)
         res.stdout =~ /Set '(.+?)' persistent and owned by uid (.+?)/
         if $1.to_s != options[:name]
           raise "TUN/TAP interface name mismatch !"
         end
         Vagrant::Util::Subprocess.execute("ifconfig", options[:name], options[:host_ip]+"/24", "up", retryable: true)
         Vagrant::Util::Subprocess.execute("sysctl", "-w", "net.ipv4.ip_forward=1", retryable: true)
         Vagrant::Util::Subprocess.execute("iptables", "-t", "nat", "-A" , "POSTROUTING", "-s", "192.168.0.2", "-o", "enp0s3", "-j", "MASQUERADE" ,retryable: true)
         # Run DHCP server (see patched version of https://github.com/aktowns/ikxDHCP.git)
         # pid = Process.fork
         # if pid.nil? then
         #  # In child
         #  RUN THE DHCPD function
         # else
         #  # In parent
         #  Process.detach(pid)
         # end
         # Set iptables MASQUERADE according to the ip address provided by the DHCP server to the guest
      end
        
    end
  end
end

        
