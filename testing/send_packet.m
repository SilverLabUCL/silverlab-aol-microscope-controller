function out = send_packet( ~, destination, sender, data )
    packet_dec = [destination, sender, data];
    packet_hex = lower(reshape(dec2hex(packet_dec)', 1, []));
    if length(data) < 30
        if exist('mock.txt','file')
            delete('mock.txt')
        end
    end
    fid = fopen('mock.txt', 'a+');
    fprintf(fid, '%s\n', packet_hex);
    fclose(fid);
    out = 0;
end

