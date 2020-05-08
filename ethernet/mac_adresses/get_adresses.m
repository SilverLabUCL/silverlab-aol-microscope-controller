function [mac_adress, send_idx, ip] = get_adresses(adapter_name)
    [mac, st] = MACAddress(1);
    send_idx = int32(find(contains({st.Description}, adapter_name)));
    if isempty(send_idx)
        error_box(['No device containing ',adapter_name,' were found. MAC adress could not be resolved. Check that your Ethernet interface name in setup.ini is right.'], 0);
    end
    ip = st(send_idx).IPv4_address;
    mac_adress = uint8(sscanf(mac{send_idx}, '%2x%*c', 6))';
    send_idx = send_idx-1;
end