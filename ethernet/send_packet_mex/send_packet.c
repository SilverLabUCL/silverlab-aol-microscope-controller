/*=================================================================
 *      Sends ethernet packets for the synthesiser FPGA
 *
 *      The calling syntax is:
 *
 *        error_code = send_packet(destination_address, sender_address, packet)
 *
 *      Error codes are
 *          0 - success
 *          1 - cannot find devices
 *          2 - cannot open adaptor
 *          3 - unable to send packet
 *
 *      This is a MEX-file for MATLAB.
 *=================================================================*/

#include <math.h>
#include "pcap.h"
#include "mex.h"

static pcap_t *fp;

unsigned int open(int device_index) {
	pcap_if_t *alldevs;
	pcap_if_t *d;
	
	char errbuf[PCAP_ERRBUF_SIZE];
	int i;

	if (pcap_findalldevs(&alldevs, errbuf) == -1) {
		return 1; // cannot find devices
	}

	/* Jump to the selected adapter */
	for (d = alldevs, i = 0; i < device_index; d = d->next, i++);

	if ((fp = pcap_open_live(d->name,
		65536,			// portion of the packet to capture. It doesn't matter in this case 
		1,				// promiscuous mode (nonzero means promiscuous)
		1000,			// read timeout
		errbuf			// error buffer
		)) == NULL)
	{
		return 2; // unable to open the adapter
	} 
    return 0;
}

unsigned int close() {
    pcap_close(fp);
}

unsigned int sendPacket(int device_index, unsigned char *dest_addr, unsigned char *send_addr, unsigned char *data, int packet_length){
	unsigned char *packet = (unsigned char*)malloc(packet_length);

    int i;

	for (i = 0; i < 6; i++) {
		packet[i] = dest_addr[i];
	}
	for (i = 6; i < 12; i++) {
		packet[i] = send_addr[i - 6];
	}     
	for (i = 12; i < packet_length; i++) {
		packet[i] = data[i - 12];
	}
	if (pcap_sendpacket(fp,	// Adapter
		packet,				// buffer with the packet
		packet_length		// size
		) != 0)
	{
		return 3; // unable to send packet
	}
	return 4;
}

void errorCheck(int nlhs, int nrhs)
{
    if (nrhs != 4) {
        mexErrMsgTxt("I receive 4 args: device_id, destination_address, source_address, packet_data");
    }
    return;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{    
	double error_code;
	unsigned char *data, *dest_addr, *send_addr;
	int packet_length, *device_index;
    
	errorCheck(nlhs, nrhs);
    
    device_index = mxGetPr(prhs[0]);
    dest_addr = mxGetPr(prhs[1]);
    send_addr = mxGetPr(prhs[2]);
    data = mxGetPr(prhs[3]);
    packet_length = mxGetN(prhs[3]) + 12;
	
    if(*device_index >= 0) {
        error_code = open(*device_index);
    } else if(*device_index < -1) {
        close();
        error_code = 5;
    } else {
        error_code = sendPacket(*device_index, dest_addr, send_addr, data, packet_length);
    }
    plhs[0] = mxCreateDoubleScalar(error_code);
    return;
}