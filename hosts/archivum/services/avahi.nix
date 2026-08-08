{
  ...
}:

{
  services.avahi = {
    enable = true;
    ipv4 = true;
    ipv6 = true;

    publish = {
      enable = true;
      userServices = true;
      domain = true;
      hinfo = true;
    };

    nssmdns4 = true;
    nssmdns6 = true;
    openFirewall = true;

    allowInterfaces = [
      "enp100s0f0np0"
      "enp100s0f1np1"
      "enp102s0"
      "enp103s0"
    ];

    extraServiceFiles = {
      smb = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
          <service>
            <type>_device-info._tcp</type>
            <port>0</port>
            <txt-record>model=RackMac</txt-record>
          </service>
        </service-group>
      '';
    };
  };
}
