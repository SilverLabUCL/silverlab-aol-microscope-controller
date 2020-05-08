#include "NiFpga.h"
#include <mex.h>
#include <string.h>
#include "pipe.h"
#include "pthread.h"
#include <windows.h>
#ifdef __cplusplus //need to link against "$matlabPATH\extern\lib\win64\microsoft\libut.lib" or "$matlabPATH\extern\lib\win32\microsoft\libut.lib"
extern "C" bool utIsInterruptPending();
#else
extern bool utIsInterruptPending();
#endif

static int PIPE_SIZE = 65535 * 2048; // 32 times fifo
static volatile bool stop_threads = false;
static pipe_consumer_t* pipe_reader[2];
static pthread_t thread;
static FILE* fp[2];
//static FILE* running_tag[1];
//static uint32_t flag_2_write = 2147483990; // from CFPGADAQ file - may change
//static uint32_t flag_2_read = 2147483986; // from CFPGADAQ file - may change

typedef struct { 
    pipe_producer_t* producer[2];
    NiFpga_Session session;
    uint32_t nElem;
    uint32_t timeout;
} read_ctx;

static read_ctx ctx;

//cf case 5060, 5061, 5062 for NiFPGA read
void clean_up_fifos(pipe_producer_t* out1, pipe_producer_t* out2){ 
    //mexPrintf("        ...C PIPE : Stopping pipes thread...\n");
	pipe_producer_free(out1);
	pipe_producer_free(out2);
}

int stop() {
 return 0;   
}


static void* move_fifo_to_pipe(void* ctx) // copy from fifo to pipe
{
	uint32_t data1[32768]; // bigger than hardware fifo
	uint32_t data2[32768];
	size_t elemRemaining1 = 0;
	size_t elemRemaining2 = 0;
    //size_t test_el = 0;
    //size_t counter = 0;
    //size_t crash_limit = 65535 * 1024; // (PIPE_SIZE / 2)
    //size_t pt_counter = 0;
	size_t nElemVariable1 = 0;
	size_t nElemVariable2 = 0;
	NiFpga_Status status = 0;
	uint32_t address = 0;
    read_ctx* context = (read_ctx*)ctx;
    
    pipe_producer_t* out1 = context->producer[0];
	pipe_producer_t* out2 = context->producer[1];
    NiFpga_Session session = context->session;
    uint32_t nElem = context->nElem;
    uint32_t timeout = context->timeout;

	nElemVariable1 = nElem;
	nElemVariable2 = nElem;
	while (true)
	{ 
		if (utIsInterruptPending())
		{
            //int tag = write_or_read_running_tag(1,0);
            //int tag = NiFpga_WriteU8(session, flag_2_write, (uint8_t)0);
			clean_up_fifos(out1, out2); //interrupt cleanup detection before read
			return 0;
		}
		if (stop_threads) //if live scan is set to 0 from code 5060 is called, and stop_threads is set to true
		{
			break;
		}

        // Warning - If you change the FIFOs (number, name etc...), you  may 
        // need to adjust the memory adresses to match the compiled lvbitx file
        // There is also a change to do in Read pipe (fcn 5061)
        status = NiFpga_ReadFifoU32(context->session, (uint32_t)2, data1, nElemVariable1, timeout, &elemRemaining1); 
        if (status != 0)
        {
            mexPrintf("%i ...\n", status);
        }
        status = NiFpga_ReadFifoU32(context->session, (uint32_t)3, data2, nElemVariable2, timeout, &elemRemaining2);
        if (status != 0)
        {
            mexPrintf("%i ...\n", status);
        }
        
        //pt_counter = pt_counter + nElemVariable1;
        //mexPrintf("Round %i - Reading %i elements in ch1, %i remaining and %i elements in ch2, %i remaining ...\n", counter,nElemVariable1,elemRemaining1,nElemVariable2,elemRemaining2);
        //mexPrintf("element read : %i %i ...\n", pt_counter, PIPE_SIZE/4);

//         if (pt_counter > crash_limit)
//         {
//             mexPrintf("FIFO SAFETY LIMIT REACHED ...\n");
//             int tag = write_or_read_running_tag(1,0);
// 			clean_up_fifos(out1, out2); //interrupt cleanup detection before read
// 			return 0;
//         }
//        
        pipe_push(out1, data1, nElemVariable1);
        pipe_push(out2, data2, nElemVariable2);
        nElemVariable1 = elemRemaining1 < nElem ? elemRemaining1 : nElem;
        nElemVariable2 = elemRemaining2 < nElem ? elemRemaining2 : nElem;
        //counter = counter + 1;
	}
    
    //"clean" cleanup
    clean_up_fifos(out1, out2); 
	return 0;
}

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
	uint32_t func = *(uint32_t*)mxGetData(prhs[0]);
	plhs[0] = mxCreateNumericMatrix(1,1,mxINT32_CLASS,mxREAL);
	NiFpga_Status *status = (NiFpga_Status *)mxGetData(plhs[0]);

	switch(func)
	{
	case 0: // Initialize
	{
		*status = NiFpga_Initialize();
		break;
	}
	case 1: // Finalize
	{
		*status = NiFpga_Finalize();
		break;
	}
	case 2: // Open
	{
		size_t strlen;
		strlen = mxGetN(prhs[1])*sizeof(char)+1;
		char* bitfile = (char *)mxMalloc(strlen);
		mxGetString(prhs[1], bitfile, strlen);
		strlen = mxGetN(prhs[2])*sizeof(char)+1;
		char* signature = (char *)mxMalloc(strlen);
		mxGetString(prhs[2], signature, strlen);
		strlen = mxGetN(prhs[3])*sizeof(char)+1;
		char* resource = (char *)mxMalloc(strlen);
		mxGetString(prhs[3], resource, strlen);
		uint32_t attribute = *(uint32_t*)mxGetData(prhs[4]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		NiFpga_Session * session = (NiFpga_Session *)mxGetData(plhs[1]);
		*status = NiFpga_Open(bitfile, signature, resource, attribute, session);
		mxFree(bitfile);
		mxFree(signature);
		mxFree(resource);
		break;
	}
	case 3: // Close
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t attribute = *(uint32_t*)mxGetData(prhs[2]);
		*status = NiFpga_Close(session, attribute);
		break;
	}
	case 4: // Run
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t attribute = *(uint32_t*)mxGetData(prhs[2]);
		*status = NiFpga_Run(session, attribute);
		break;
	}
	case 5: // Abort
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		*status = NiFpga_Abort(session);
		break;
	}
	case 6: // Reset
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		*status = NiFpga_Reset(session);
		break;
	}
	case 7: // Download
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		*status = NiFpga_Download(session);
		break;
	}	
	case 8: // Reserve Irq Context
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		NiFpga_IrqContext * context = (NiFpga_IrqContext *)mxGetData(plhs[1]);
		*status = NiFpga_ReserveIrqContext(session, context);
		break;
	}
	case 9: // Unreserve Irq Context
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		NiFpga_IrqContext context = *(NiFpga_IrqContext*)mxGetData(prhs[2]);
		*status =  NiFpga_UnreserveIrqContext(session, context);
		break;
	}
	case 10: // Wait On Irq
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		NiFpga_IrqContext context = *(NiFpga_IrqContext*)mxGetData(prhs[2]);
		uint32_t irqs = *(uint32_t*)mxGetData(prhs[3]);
		uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		uint32_t * irqsAsserted = (uint32_t*)mxGetData(plhs[1]);
		plhs[2] = mxCreateNumericMatrix(1,1,mxUINT8_CLASS,mxREAL);
		NiFpga_Bool * timedOut = (NiFpga_Bool*)mxGetData(plhs[2]);
		*status = NiFpga_WaitOnIrqs(session, context, irqs, timeout, irqsAsserted, timedOut);
		break;
	}
	case 11: // Acknowlege Irq
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t irqs = *(uint32_t*)mxGetData(prhs[2]);
		*status = NiFpga_AcknowledgeIrqs(session, irqs);
		break;
	}
	case 12: // Configure Fifo
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        uint32_t depth = *(uint32_t*)mxGetData(prhs[3]);
        *status = NiFpga_ConfigureFifo(session, address, depth);
        break;
	}
	case 13: // Start Fifo
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        *status = NiFpga_StartFifo(session, address);
        break;
	}
	case 14: // Stop Fifo
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        *status = NiFpga_StopFifo(session, address);
        break;
	}
	case 100: // ReadBool
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxUINT8_CLASS,mxREAL);
		NiFpga_Bool* value = (NiFpga_Bool *)mxGetData(plhs[1]);
		*status = NiFpga_ReadBool(session, address, value);
		break;
	}
	case 101: // ReadI8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxINT8_CLASS,mxREAL);
		int8_t* value = (int8_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadI8(session, address, value);
		break;
	}
	case 102: // ReadU8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxUINT8_CLASS,mxREAL);
		uint8_t* value = (uint8_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadU8(session, address, value);
		break;
	}
	case 103: // ReadI16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxINT16_CLASS,mxREAL);
		int16_t* value = (int16_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadI16(session, address, value);
		break;
	}
	case 104: // ReadU16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxUINT16_CLASS,mxREAL);
		uint16_t* value = (uint16_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadU16(session, address, value);
		break;
	}
	case 105: // ReadI32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxINT32_CLASS,mxREAL);
		int32_t* value = (int32_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadI32(session, address, value);
		break;
	}
	case 106: // ReadU32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		uint32_t* value = (uint32_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadU32(session, address, value);
		break;
	}
	case 107: // ReadI64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxINT64_CLASS,mxREAL);
		int64_t* value = (int64_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadI64(session, address, value);
		break;
	}
	case 108: // ReadU64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		plhs[1] = mxCreateNumericMatrix(1,1,mxUINT64_CLASS,mxREAL);
		uint64_t* value = (uint64_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadU64(session, address, value);
		break;
	}
	case 200: // WriteBool
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		NiFpga_Bool value = *(NiFpga_Bool *)mxGetData(prhs[3]);
		*status = NiFpga_WriteBool(session, address, value);
		break;
	}
	case 201: // WriteI8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		int8_t value = *(int8_t *)mxGetData(prhs[3]);
		*status = NiFpga_WriteI8(session, address, value);
		break;
	}
	case 202: // WriteU8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint8_t value = *(uint8_t *)mxGetData(prhs[3]);
		*status = NiFpga_WriteU8(session, address, value);
		break;
	}
	case 203: // WriteI16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		int16_t value = *(int16_t *)mxGetData(prhs[3]);
		*status = NiFpga_WriteI16(session, address, value);
		break;
	}
	case 204: // WriteU16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint16_t value = *(uint16_t *)mxGetData(prhs[3]);
		*status = NiFpga_WriteU16(session, address, value);
		break;
	}
	case 205: // WriteI32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		int32_t value = *(int32_t *)mxGetData(prhs[3]);
		*status = NiFpga_WriteI32(session, address, value);
		break;
	}
	case 206: // WriteU32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t value = *(uint32_t *)mxGetData(prhs[3]);
		*status = NiFpga_WriteU32(session, address, value);
		break;
	}
	case 207: // WriteI64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		int64_t value = *(int64_t *)mxGetData(prhs[3]);
		*status = NiFpga_WriteI64(session, address, value);
		break;
	}
	case 208: // WriteU64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint64_t value = *(uint64_t *)mxGetData(prhs[3]);
		*status = NiFpga_WriteU64(session, address, value);
		break;
	}
	case 300: // ReadArrayBool
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxUINT8_CLASS, mxREAL);
		NiFpga_Bool * array = (NiFpga_Bool *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayBool(session, address, array, size);
		break;
	}
	case 301: // ReadArrayI8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxINT8_CLASS, mxREAL);
		int8_t * array = (int8_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayI8(session, address, array, size);
		break;
	}
	case 302: // ReadArrayU8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxUINT8_CLASS, mxREAL);
		uint8_t * array = (uint8_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayU8(session, address, array, size);
		break;
	}
	case 303: // ReadArrayI16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxINT16_CLASS, mxREAL);
		int16_t * array = (int16_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayI16(session, address, array, size);
		break;
	}
	case 304: // ReadArrayU16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxUINT16_CLASS, mxREAL);
		uint16_t * array = (uint16_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayU16(session, address, array, size);
		break;
	}
	case 305: // ReadArrayI32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxINT32_CLASS, mxREAL);
		int32_t * array = (int32_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayI32(session, address, array, size);
		break;
	}
	case 306: // ReadArrayU32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxUINT32_CLASS, mxREAL);
		uint32_t * array = (uint32_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayU32(session, address, array, size);
		break;
	}
	case 307: // ReadArrayI64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxINT64_CLASS, mxREAL);
		int64_t * array = (int64_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayI64(session, address, array, size);
		break;
	}
	case 308: // ReadArrayU64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[3]);
		plhs[1] = mxCreateNumericMatrix(size, 1, mxUINT64_CLASS, mxREAL);
		uint64_t * array = (uint64_t *)mxGetData(plhs[1]);
		*status = NiFpga_ReadArrayU64(session, address, array, size);
		break;
	}
	case 400: // WriteArrayBool
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const NiFpga_Bool * array = (const NiFpga_Bool *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayBool(session, address, array, size);
		break;
	}
	case 401: // WriteArrayI8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const int8_t * array = (const int8_t *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayI8(session, address, array, size);
		break;
	}
	case 402: // WriteArrayU8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const uint8_t * array = (const uint8_t *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayU8(session, address, array, size);
		break;
	}
	case 403: // WriteArrayI16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const int16_t * array = (const int16_t *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayI16(session, address, array, size);
		break;
	}
	case 404: // WriteArrayU16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const uint16_t * array = (const uint16_t *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayU16(session, address, array, size);
		break;
	}
	case 405: // WriteArrayI32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const int32_t * array = (const int32_t *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayI32(session, address, array, size);
		break;
	}
	case 406: // WriteArrayU32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const uint32_t * array = (const uint32_t *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayU32(session, address, array, size);
		break;
	}
	case 407: // WriteArrayI64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const int64_t * array = (const int64_t *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayI64(session, address, array, size);
		break;
	}
	case 408: // WriteArrayU64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
		const uint64_t * array = (const uint64_t *)mxGetData(prhs[3]);
		uint32_t size = *(uint32_t*)mxGetData(prhs[4]);
		*status = NiFpga_WriteArrayU64(session, address, array, size);
		break;
	}
	case 500: // ReadFifoBool
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxUINT8_CLASS, mxREAL);
        NiFpga_Bool *data = (NiFpga_Bool*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoBool(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
	case 501: // ReadFifoI8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxINT8_CLASS, mxREAL);
        int8_t *data = (int8_t*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoI8(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
	case 502: // ReadFifoU8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxUINT8_CLASS, mxREAL);
        uint8_t *data = (uint8_t*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoU8(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
	case 503: // ReadFifoI16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxINT16_CLASS, mxREAL);
        int16_t *data = (int16_t*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoI16(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
	case 504: // ReadFifoU16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxUINT16_CLASS, mxREAL);
        uint16_t *data = (uint16_t*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoU16(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
	case 505: // ReadFifoI32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxINT32_CLASS, mxREAL);
        int32_t *data = (int32_t*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoI32(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
	case 506: // ReadFifoU32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxUINT32_CLASS, mxREAL);
        uint32_t *data = (uint32_t*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoU32(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
    case 5060: // start fifo thread
	{
		stop_threads = false;
        
        //int tag = write_or_read_running_tag(0,0);
        //NiFpga_Status tag = NiFpga_ReadU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_read, (NiFpga_Bool*)1);
        
        //if (tag == 0) { // if files doesn t exist or exist and is stopped
            //int tag = write_or_read_running_tag(1,1);
           // int tag = NiFpga_WriteU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_write, (uint8_t)1);
            //mexPrintf("        ...C PIPE : Starting pipes thread...\n");

            ctx.session = *(NiFpga_Session*)mxGetData(prhs[1]);
            ctx.nElem = *(uint32_t*)mxGetData(prhs[3]);
            ctx.timeout = *(uint32_t*)mxGetData(prhs[4]);

            for (int m = 0; m < 2; m++)
            {
                pipe_t* the_pipe = pipe_new(sizeof(uint32_t), PIPE_SIZE);
                pipe_producer_t* prod = pipe_producer_new(the_pipe);
                pipe_consumer_t* cons = pipe_consumer_new(the_pipe);
                ctx.producer[m] = prod;
                pipe_reader[m] = cons;
                pipe_free(the_pipe);
            }
            pthread_create(&thread, NULL, &move_fifo_to_pipe, &ctx);
//         }
//         else {
//             stop();
//         }
		break;
	}
    case 5061: // read pipe
    {
        //check if scan is running
        //int tag = write_or_read_running_tag(0,0);
//         int tag = NiFpga_ReadU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_read, (uint8_t*)0);
//  
//         if(tag == 1) //if running, then read
//         {
            size_t nElem = *(size_t*)mxGetData(prhs[3]);
            plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxUINT32_CLASS, mxREAL);
            uint32_t *data = (uint32_t*)mxGetData(plhs[1]);
            plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
            size_t *elemRead = (size_t*)mxGetData(plhs[2]);
            uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
            *elemRead = pipe_pop_eager(pipe_reader[address - 2], data, nElem); // -2 because HW adresses are 2 and 3 for the FIFOs but we want idx 0 and 1
//         }
//         else {
//            stop_threads = true; 
//         }
		break;
    }
    case 5062: // stop fifo thread
	{
        //int tag = write_or_read_running_tag(0,0);
//         int tag = NiFpga_ReadU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_read, (uint8_t*)0);
//         
//         if (tag == 1) { // if thread is still running
            //int tag = write_or_read_running_tag(1,0);
  //          int tag = NiFpga_WriteU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_write, (uint8_t)0);
            stop_threads = true;
            pthread_join(thread, NULL);
            pipe_consumer_free(pipe_reader[0]);
            pipe_consumer_free(pipe_reader[1]);
//         }
//         else {
//             stop();
//         }
		break;
	}
    
    case 5063: // create bin files
	{
		stop_threads = false;

        //int tag = write_or_read_running_tag(0,0);
//         int tag = NiFpga_ReadU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_read, (uint8_t*)0);
//         
//         if (tag == 0) { // if files doesn t exist or exist and is stopped
            fp[0] = fopen("data1.bin", "ab");
            fp[1] = fopen("data2.bin", "ab");
            //int tag = write_or_read_running_tag(1,1);
       //     int tag = NiFpga_WriteU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_write, (uint8_t)1);
            //mexPrintf("        ...C PIPE : Starting pipes thread...\n");

            ctx.session = *(NiFpga_Session*)mxGetData(prhs[1]);
            ctx.nElem = *(uint32_t*)mxGetData(prhs[3]);
            ctx.timeout = *(uint32_t*)mxGetData(prhs[4]);

            for (int m = 0; m < 2; m++)
            {
                pipe_t* the_pipe = pipe_new(sizeof(uint32_t), PIPE_SIZE);
                pipe_producer_t* prod = pipe_producer_new(the_pipe);
                pipe_consumer_t* cons = pipe_consumer_new(the_pipe);
                ctx.producer[m] = prod;
                pipe_reader[m] = cons;
                pipe_free(the_pipe);
            }
            pthread_create(&thread, NULL, &move_fifo_to_pipe, &ctx);
//         }
//         else {
//             stop();
//         }
		break;
	}
    case 5064: // read pipe and dump data to bin file
    {
        //check if scan is running
        //int tag = write_or_read_running_tag(0,0);
//         int tag = NiFpga_ReadU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_read, (uint8_t*)0);
//  
//         if(tag == 1) //if running, then read
//         {
            size_t nElem = *(size_t*)mxGetData(prhs[3]);
            plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxUINT32_CLASS, mxREAL);
            uint32_t *data = (uint32_t*)mxGetData(plhs[1]);
            plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
            size_t *elemRead = (size_t*)mxGetData(plhs[2]);
            uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
            *elemRead = pipe_pop_eager(pipe_reader[address - 2], data, nElem); // -2 because HW adresses are 2 and 3 for the FIFOs but we want idx 0 and 1
            fwrite(data, sizeof(uint32_t), *elemRead, fp[address - 2]);
//         }
//         else {
//            stop_threads = true; 
//         }
		break;
    }
    case 5065: // stop fifo thread and close file
	{
        //int tag = write_or_read_running_tag(0,0);
//         int tag = NiFpga_ReadU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_read, (uint8_t*)0);
//         
//         if (tag == 1) { // if thread is still running
            //int tag = write_or_read_running_tag(1,0);
          //  int tag = NiFpga_WriteU8(*(NiFpga_Session*)mxGetData(prhs[1]), flag_2_write, (uint8_t)0);
            stop_threads = true;
            pthread_join(thread, NULL);
            pipe_consumer_free(pipe_reader[0]);
            pipe_consumer_free(pipe_reader[1]);
            fclose(fp[0]);
            fclose(fp[1]);
//         }
//         else {
//             stop();
//         }
		break;
	}
    
	case 507: // ReadFifoI64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxINT64_CLASS, mxREAL);
        int64_t *data = (int64_t*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoI64(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
	case 508: // ReadFifoU64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        size_t nElem = *(size_t*)mxGetData(prhs[3]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[4]);
        plhs[1] = mxCreateNumericMatrix(nElem > 0 ? nElem : 1, 1, mxUINT64_CLASS, mxREAL);
        uint64_t *data = (uint64_t*)mxGetData(plhs[1]);
        plhs[2] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * elemRemaining = (size_t *)mxGetData(plhs[2]);
        *status = NiFpga_ReadFifoU64(session, address, data, nElem, timeout, elemRemaining);
		break;
	}
	case 600: // WriteFifoBool
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        NiFpga_Bool *data = (NiFpga_Bool*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoBool(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	case 601: // WriteFifoI8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        int8_t *data = (int8_t*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoI8(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	case 602: // WriteFifoU8
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        uint8_t *data = (uint8_t*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoU8(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	case 603: // WriteFifoI16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        int16_t *data = (int16_t*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoI16(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	case 604: // WriteFifoU16
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        uint16_t *data = (uint16_t*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoU16(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	case 605: // WriteFifoI32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        int32_t *data = (int32_t*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoI32(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	case 606: // WriteFifoU32
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        uint32_t *data = (uint32_t*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoU32(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	case 607: // WriteFifoI64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        int64_t *data = (int64_t*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoI64(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	case 608: // WriteFifoU64
	{
        NiFpga_Session session = *(NiFpga_Session*)mxGetData(prhs[1]);
		uint32_t address = *(uint32_t*)mxGetData(prhs[2]);
        uint64_t *data = (uint64_t*)mxGetData(prhs[3]);
        uint32_t nElem = *(uint32_t*)mxGetData(prhs[4]);
        uint32_t timeout = *(uint32_t*)mxGetData(prhs[5]);
        plhs[1] = mxCreateNumericMatrix(1,1,mxUINT32_CLASS,mxREAL);
		size_t * emptyElementsRemaining = (size_t *)mxGetData(plhs[1]);
        *status = NiFpga_WriteFifoU64(session, address, data, nElem, timeout, emptyElementsRemaining);
		break;
	}
	default:
	{
		*status = -1;
		break;
	}
	}
}
