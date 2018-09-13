/*************************************************************************
* Description:                                                           *
* The following is the microC code that will run on the Voice            *
* Manipulator.  It handles audio data movement, Bluetooth control,       *
* and user interface.                                                    *
**************************************************************************/


/*************************************************************************
* DEFINES AND INCLUDES                                                   *
**************************************************************************/
#include <stdio.h>
#include <math.h>
#include <string.h>
#include "includes.h"
#include "altera_up_avalon_audio.h"
#include "altera_up_avalon_audio_and_video_config.h"
#include "altera_avalon_fifo_util.h"
#include "altera_avalon_fifo_regs.h"
#include "altera_avalon_pio_regs.h"
#include "samples.h"


/* Definition of Task Stacks and priorities */
#define     AUDIO_DATA_TASK_STACKSIZE   65536
#define     LCD_TASK_STACKSIZE          2084
#define     BT_TASK_STACKSIZE           2048
#define     AUDIO_DATA_TASK_PRIORITY    3
#define     LCD_TASK_PRIORITY           1
#define     BT_TASK_PRIORITY            2
OS_STK      audio_data_task_stk[AUDIO_DATA_TASK_STACKSIZE];
OS_STK      LCD_task_stk[LCD_TASK_STACKSIZE];
OS_STK      BT_task_stk[BT_TASK_STACKSIZE];
OS_EVENT    *LCDSem;

/* Other defines */
#define     AUDIO_BUFFER_SIZE   128
#define     ECHO_BUFFER_SIZE 	4096

#define     FREQ_SHIFT_P3_4     11
#define     FREQ_SHIFT_P2_4     -7
#define     FREQ_SHIFT_P1_4     3
#define     FREQ_SHIFT_0_4      0
#define     FREQ_SHIFT_N1_4     -2
#define     FREQ_SHIFT_N2_4     -5

#define     FREQ_SHIFT_P3_5     11
#define     FREQ_SHIFT_P2_5     7
#define     FREQ_SHIFT_P1_5     3
#define     FREQ_SHIFT_0_5      0
#define     FREQ_SHIFT_N1_5     2
#define     FREQ_SHIFT_N2_5     5

#define		MIN_VOLUME			91
#define 	MAX_VOLUME			127
#define		VOLUME_SHIFT		3
#define		MAX_ECHO_NEG_DELAY	4095
#define		MIN_ECHO_NEG_DELAY	95
#define		ECHO_DELAY_SHIFT	800

#define 	NUM_BUTTONS			4
#define		NUM_SINE_SAMPLES	320










/*************************************************************************
* INTERRUPTS                                                             *
**************************************************************************/

//increments the current parameter
static void handle_button0_interrupts(void* context, alt_u32 id)
{
    alt_up_av_config_dev * audio_config_dev;
    audio_config_dev = alt_up_av_config_open_dev("/dev/audio_and_video_config_0");
    int* params = (int *) context;
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(BUTTON0_BASE, 0);

    switch(params[0])
    {
        case 1: // increase volume
            if(params[1] < MAX_VOLUME)
            {
                params[1] += VOLUME_SHIFT;
                //write to the audio codec register to change volume
                alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x2, (params[1]+0x180));
            }
            break;
        case 2: // increase echo delay
            if(params[2] > MIN_ECHO_NEG_DELAY)
            {
                params[2] = params[2] - ECHO_DELAY_SHIFT;
            }
            break;
        case 3: // turn on echo decay if not already on
            if (params[3] == 0)
            {
                params[3] = 1;
            }
        case 4: // increase frequency shift
            switch(params[4])
            {
                case FREQ_SHIFT_P3_4: //highest frequency shift up, +3
                    //do nothing
                    break;
                case FREQ_SHIFT_P2_4: //second highest frequency shift up, +2
                    params[4] = FREQ_SHIFT_P3_4;
                    params[5] = FREQ_SHIFT_P3_5;
                    break;
                case FREQ_SHIFT_P1_4: //third highest frequency shift up, +1
                    params[4] = FREQ_SHIFT_P2_4;
                    params[5] = FREQ_SHIFT_P2_5;
                    break;
                case FREQ_SHIFT_0_4: //no frequency shift, 0
                    params[4] = FREQ_SHIFT_P1_4;
                    params[5] = FREQ_SHIFT_P1_5;
                    break;
                case FREQ_SHIFT_N1_4: //second highest frequency shift down, -1
                    params[4] = FREQ_SHIFT_0_4;
                    params[5] = FREQ_SHIFT_0_5;
                    break;
                case FREQ_SHIFT_N2_4: //highest frequency shift down, -2
                    params[4] = FREQ_SHIFT_N1_4;
                    params[5] = FREQ_SHIFT_N1_5;
                    break;
            }

    }
    OSSemPost(LCDSem);
}

//decrements current parameter
static void handle_button1_interrupts(void* context, alt_u32 id)
{
    alt_up_av_config_dev * audio_config_dev;
    audio_config_dev = alt_up_av_config_open_dev("/dev/audio_and_video_config_0");
    int* params = (int *) context;
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(BUTTON1_BASE, 0);

    switch(params[0])
    {
        case 1: // decrease volume
            if(params[1] > MIN_VOLUME)
            {
                params[1] -= VOLUME_SHIFT;
                //write to audio codec register to change volume
                alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x2, (params[1]+0x180));
            }
            break;
        case 2: // decrease echo delay
            if (params[2] < MAX_ECHO_NEG_DELAY)
            {
                params[2] = params[2] + ECHO_DELAY_SHIFT;
            }
            break;
        case 3: // turn off echo decay if not already off
            if (params[3] == 1)
            {
                params[3] = 0;
            }
        case 4: // decrease frequency shift
            switch(params[4])
            {
                case FREQ_SHIFT_P3_4: //highest frequency shift up, +3
                    params[4] = FREQ_SHIFT_P2_4;
                    params[5] = FREQ_SHIFT_P2_5;
                    break;
                case FREQ_SHIFT_P2_4: //second highest frequency shift up, +2
                    params[4] = FREQ_SHIFT_P1_4;
                    params[5] = FREQ_SHIFT_P1_5;
                    break;
                case FREQ_SHIFT_P1_4: //third highest frequency shift up, +1
                    params[4] = FREQ_SHIFT_0_4;
                    params[5] = FREQ_SHIFT_0_5;
                    break;
                case FREQ_SHIFT_0_4: //no frequency shift, 0
                    params[4] = FREQ_SHIFT_N1_4;
                    params[5] = FREQ_SHIFT_N1_4;
                    break;
                case FREQ_SHIFT_N1_4: //second highest frequency shift down, -1
                    params[4] = FREQ_SHIFT_N2_4;
                    params[5] = FREQ_SHIFT_N2_5;
                    break;
                case FREQ_SHIFT_N2_4: //highest frequency shift down, -2
                    //do nothing
                    break;
            }
    }
    OSSemPost(LCDSem);
}

//changes tracked parameter to next parameter
static void handle_button2_interrupts(void* context, alt_u32 id)
{
    int* params = (int *) context;
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(BUTTON2_BASE, 0);
    if(params[0] == NUM_BUTTONS)
    {
        params[0] = 1;
    }
    else
    {
        params[0]++;
    }
    OSSemPost(LCDSem);
}

//changes tracked parameter to previous parameter
static void handle_button3_interrupts(void* context, alt_u32 id)
{
    int* params = (int *) context;
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(BUTTON3_BASE, 0);
    if(params[0] == 1)
        {
            params[0] = NUM_BUTTONS;
        }
        else
        {
            params[0]--;
        }
        OSSemPost(LCDSem);
}











/*************************************************************************
* TASKS                                                                  *
**************************************************************************/


//Controls LCD Display
void LCD_task(void* pdata)
{
    //variable declaration and initialization
    INT8U err;
    FILE* lcd;
    int * params = pdata;
    int freq_value = 0;
    int echo_delay_value = 0;

    //open LCD device
    lcd = fopen("/dev/lcd_0", "w");
    if ( lcd == NULL)
        printf("Error: could not open lcd device from LCD task \n");
    else
        printf("Opened lcd device in LCD task \n");

    fprintf(lcd, "ECE492  Group 11\n");
    fprintf(lcd, "VoiceManipulator\n");

    OSTimeDlyHMSM(0, 0, 2, 0);

    while(1)
    {
        OSSemPend(LCDSem, 0, &err);

        //find which parameter is currently being modified and display user-friendly current value
        switch(params[0])
        {
            case 1:
                fprintf(lcd, "Volume:\n");
                fprintf(lcd, "%d\n", (params[1]-109)/3);
                break;

            case 2:
                fprintf(lcd, "Echo Delay:\n");
                switch(params[2])
                {
                    case 4095:
                        echo_delay_value = 0;
                        break;
                    case 3295:
                        echo_delay_value = 1;
                        break;
                    case 2495:
                        echo_delay_value = 2;
                        break;
                    case 1695:
                        echo_delay_value = 3;
                        break;
                    case 895:
                        echo_delay_value = 4;
                        break;
                    case 95:
                        echo_delay_value = 5;
                        break;
                }
                fprintf(lcd, "0.%ds\n", echo_delay_value);
                break;

            case 3:
                fprintf(lcd, "Echo Reduction:\n");
                if (params[3] == 0)
                {
                    fprintf(lcd, "Off\n");
                }
                else
                {
                    fprintf(lcd, "On\n");
                }
                break;

            case 4:
                fprintf(lcd, "Frequency Shift:\n");
                switch(params[4])
                {
                    case FREQ_SHIFT_P3_4: //highest frequency shift up, +3
                        freq_value = 3;
                        break;
                    case FREQ_SHIFT_P2_4: //second highest frequency shift up, +2
                        freq_value = 2;
                        break;
                    case FREQ_SHIFT_P1_4: //third highest frequency shift up, +1
                        freq_value = 1;
                        break;
                    case FREQ_SHIFT_0_4: //no frequency shift, 0
                        freq_value = 0;
                        break;
                    case FREQ_SHIFT_N1_4: //second highest frequency shift down, -1
                        freq_value = -1;
                        break;
                    case FREQ_SHIFT_N2_4: //highest frequency shift down, -2
                        freq_value = -2;
                        break;
                }
                fprintf(lcd, "%d\n", freq_value);
        }
    }
}



//handle Bluetooth serial data
void BT_task(void* pdata)
{
    //variable declaration and initialization
    FILE* lm20;
    char input = '\0';

    lm20 = fopen (LM20_UART_NAME, "r+");
    if (lm20 == NULL)
        printf("Error: Could not open bluetooth UART in BT task \n");
    else
        printf("Opened bluetooth UART in BT task \n");


    //configure Bluetooth for hands-free operation
    fprintf(lm20, "SET CONTROL ECHO 4\n");
    fprintf(lm20, "SET BT NAME ECE492_VM\n");
    fprintf(lm20, "SET CONTROL AUTOCALL\n");
    fprintf(lm20, "SET CONTROL CD 4 0\n");
    fprintf(lm20, "SET BT PAGEMODE 4 2000 1\n");
    fprintf(lm20, "SET BT CLASS ff0408\n");
    fprintf(lm20, "SET BT ROLE 0 f 7d00\n");
    fprintf(lm20, "SET BT AUTH * 0492\n");
    fprintf(lm20, "SET PROFILE SPP\n");
    fprintf(lm20, "SET PROFILE HFP ON\n");

    while (1)
    {
        do {
            input = getc(lm20);
            printf("%c", input);
        } while (input != EOF);

        OSTimeDlyHMSM(0, 0, 0, 100);
    }
}


// Handles audio data movement between modules and input/output
void audio_data_task(void* pdata)
{
    //variable declaration and initialization
    int * params = (int*) pdata;
    alt_up_audio_dev * audio_dev;
    alt_up_av_config_dev * audio_config_dev;

    int i = 0;
    int writeSize = 0;
    int temp_value = 0;
    unsigned int audio_buf[AUDIO_BUFFER_SIZE];
    unsigned int out_buf[4];
    unsigned int echo_buf[ECHO_BUFFER_SIZE];
    for (i = 0; i < AUDIO_BUFFER_SIZE ; i++)
    {
        audio_buf[i] = 0;
    }
    for (i = 0; i < 4; i++)
    {
        out_buf[i] = 0;
    }
    for (i = 0; i < ECHO_BUFFER_SIZE ; i++)
    {
        echo_buf[i] = 0;
    }

    //open devices
    audio_dev = alt_up_audio_open_dev ("/dev/audio_0");
    if ( audio_dev == NULL)
        printf("Error: could not open audio device \n");
    else
        printf("Opened audio device \n");

    audio_config_dev = alt_up_av_config_open_dev("/dev/audio_and_video_config_0");
    if ( audio_config_dev == NULL)
        printf("Error: could not open audio config device \n");
    else
        printf("Opened audio config device \n");

    //Configure WM8731
    alt_up_audio_reset_audio_core(audio_dev);
    alt_up_av_config_reset(audio_config_dev);

    alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x0, 0x17);
    alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x1, 0x17);
    alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x2, 0x79);
    alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x3, 0x79);
    alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x4, 0x15);
    alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x5, 0x06);
    alt_up_av_config_write_audio_cfg_register(audio_config_dev, 0x6, 0x00);

    //initialize FIFOs coming in and out of DSP
    altera_avalon_fifo_init(CURRENT_AUDIO_IN_IN_CSR_BASE, 0x0, 1, CURRENT_AUDIO_IN_IN_FIFO_DEPTH-1);
    altera_avalon_fifo_init(CURRENT_AUDIO_OUT_IN_CSR_BASE, 0x0, 1, CURRENT_AUDIO_OUT_OUT_FIFO_DEPTH-1);
    altera_avalon_fifo_init(SINE_IN_IN_CSR_BASE, 0x0, 1, SINE_IN_IN_FIFO_DEPTH-1);
    altera_avalon_fifo_init(COSINE_IN_IN_CSR_BASE, 0x0, 1, COSINE_IN_IN_FIFO_DEPTH-1);
    altera_avalon_fifo_init(ECHO_IN_IN_CSR_BASE, 0x0, 1, ECHO_IN_IN_FIFO_DEPTH-1);
    altera_avalon_fifo_init(ECHO_DELAY_IN_IN_CSR_BASE, 0x0, 1, ECHO_DELAY_IN_IN_FIFO_DEPTH-1);
    altera_avalon_fifo_init(ECHO_OUT_IN_CSR_BASE, 0x0, 1, ECHO_OUT_OUT_FIFO_DEPTH-1);
    altera_avalon_fifo_init(PCM_IN_IN_CSR_BASE, 0x0, 1, PCM_IN_IN_FIFO_DEPTH-1);
    altera_avalon_fifo_init(PCM_OUT_IN_CSR_BASE, 0x0, 1, PCM_OUT_OUT_FIFO_DEPTH-1);

    int sin_index = 0;
    int cos_index = 80;
    int echo_writeIndex = 0;
    int echo_readIndex = 0;

    while(1)
    {
            //read the data from the left buffer
            writeSize = alt_up_audio_read_fifo_avail(audio_dev, ALT_UP_AUDIO_LEFT);
            if (writeSize >= 3)
            {
                alt_up_audio_read_fifo(audio_dev, audio_buf, 4,  ALT_UP_AUDIO_LEFT);

                //send values to the frequency shifter
                altera_avalon_fifo_write_fifo(CURRENT_AUDIO_IN_IN_BASE, CURRENT_AUDIO_IN_IN_CSR_BASE, audio_buf[0]);
                altera_avalon_fifo_write_fifo(SINE_IN_IN_BASE, SINE_IN_IN_CSR_BASE, sine_samples[sin_index]);
                altera_avalon_fifo_write_fifo(COSINE_IN_IN_BASE, COSINE_IN_IN_CSR_BASE, sine_samples[cos_index]);

                //update sinusoid index values
                sin_index = (sin_index + params[4]);
                if (sin_index >= NUM_SINE_SAMPLES)
                {
                    sin_index = sin_index - NUM_SINE_SAMPLES;
                }
                cos_index = (cos_index + params[5]);
                if (cos_index >= NUM_SINE_SAMPLES)
                {
                    cos_index = cos_index - NUM_SINE_SAMPLES;
                }

                //read output of frequency shifter and copy it into the echo buffer
                temp_value = altera_avalon_fifo_read_fifo(CURRENT_AUDIO_OUT_OUT_BASE, CURRENT_AUDIO_OUT_IN_CSR_BASE);

                echo_buf[echo_writeIndex] = temp_value;

                //update read and write indices for the echo buffer
                echo_writeIndex++;
                if(echo_writeIndex >= ECHO_BUFFER_SIZE)
                {
                    echo_writeIndex = 0;
                }
                echo_readIndex = echo_writeIndex + params[2];
                if (echo_readIndex >= ECHO_BUFFER_SIZE)
                {
                    echo_readIndex = echo_readIndex - ECHO_BUFFER_SIZE;
                }

                //input current value and delayed value
                altera_avalon_fifo_write_fifo(ECHO_IN_IN_BASE, ECHO_IN_IN_CSR_BASE, temp_value);
                altera_avalon_fifo_write_fifo(ECHO_DELAY_IN_IN_BASE, ECHO_DELAY_IN_IN_CSR_BASE, echo_buf[echo_readIndex]);

                //get output of echo generator
                audio_buf[0] = altera_avalon_fifo_read_fifo(ECHO_OUT_OUT_BASE, ECHO_OUT_IN_CSR_BASE);

                if (*(int*)SWITCH_BASE & 0x1) //up: mic to speakers; down: phone
                {
                    //audio_buf[0] = audio_buf[0];
                    audio_buf[1] = audio_buf[0];
                    audio_buf[2] = audio_buf[0];
                    audio_buf[3] = audio_buf[0];
                }
                else
                {
                    //write data to the PCM interface
                    altera_avalon_fifo_write_fifo(PCM_IN_IN_BASE, PCM_IN_IN_CSR_BASE, audio_buf[0] + 0x7fff);
                }

                if (*(int*)SWITCH_BASE & 0x1) //up: mic to speakers; down: phone
                {
                    // write data to the L and R buffers; R buffer will receive a copy of L buffer data
                    alt_up_audio_write_fifo (audio_dev, audio_buf, 4, ALT_UP_AUDIO_RIGHT);
                    alt_up_audio_write_fifo (audio_dev, audio_buf, 4, ALT_UP_AUDIO_LEFT);
                }
                else
                {
                    // output from phone to speakers
                    if (altera_avalon_fifo_read_level(PCM_OUT_IN_CSR_BASE) > 0)
                    {
						// downsample by a factor of 4 for Bluetooth audio
                        out_buf[0] = altera_avalon_fifo_read_fifo(PCM_OUT_OUT_BASE, PCM_OUT_IN_CSR_BASE) + 0x7fff;
                        out_buf[1] = out_buf[0];
                        out_buf[2] = out_buf[0];
                        out_buf[3] = out_buf[0];
                    }

                    //write data to the L and R buffers; R buffer will receive a copy of L buffer data
                    alt_up_audio_write_fifo (audio_dev, out_buf, 4, ALT_UP_AUDIO_RIGHT);
                    alt_up_audio_write_fifo (audio_dev, out_buf, 4, ALT_UP_AUDIO_LEFT);
                }
            }
    }
}


// main function
int main(void)
{

    // params: array used to pass software values between interrupts and tasks
    //   params[0] - holds the current parameters; 1 correponds to volume, 2 to echo delay, etc.
    //   params[1] - volume level
    //                  -default volume is 109 (0 on display)
    //                  -changed in steps of 3, minimum 91 (-6 on display) to maximum 127 (6 on display)
    //   params[2] - echo delay
    //                  -default echo delay is 4095, which corresponds to 0 delay (0 on display)
    //                  -this value decrements in steps of 800, where each step is an addition 0.1s in delay
    //                  -minimum value is 95, which corresponds to 0.5s delay
    //   params[3] - echo reduction
    //                  -default echo reduction is 2, which corresponds to no attenuation (1 on display)
    //                  -other option is 1, which corresponds to attenuation by a factor of 4 (0.25 on display)
    //                  -these are the only two options; zero echo is achieved by setting echo delay to 0
    //   params[4] - frequency shift
    //                  -default value is 0, which corresponds to 0 frequency shift (0 on display)
    //                  -takes on three more values for shifts above zero, and two more values for shifts below zero
    //                  -represents the step size to traverse the sine wave samples to emulate a given frequency
    //   params[5] - frequency shift
    //                  -auxiliary parameter for frequency shift, representing the step size to traverse cosine wave samples
    //                  -will either equal params[4] or be the negative
    //
    // Potential synchronization issues have been acknowledged. This array is not subject to race conditions
    // as each parameter is only written by one function. Values are written only in the interrupt routines.
    // Any other function that uses this array only reads the value.
    int params[10] = {1,109,4095,1,0,0};

    //initialize interrupts
    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(BUTTON0_BASE, 0x1);
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(BUTTON0_BASE, 0x0);
    alt_irq_register( BUTTON0_IRQ, params, handle_button0_interrupts );

    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(BUTTON1_BASE, 0x1);
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(BUTTON1_BASE, 0x0);
    alt_irq_register( BUTTON1_IRQ, params, handle_button1_interrupts );

    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(BUTTON2_BASE, 0x1);
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(BUTTON2_BASE, 0x0);
    alt_irq_register( BUTTON2_IRQ, params, handle_button2_interrupts );

    IOWR_ALTERA_AVALON_PIO_IRQ_MASK(BUTTON3_BASE, 0x1);
    IOWR_ALTERA_AVALON_PIO_EDGE_CAP(BUTTON3_BASE, 0x0);
    alt_irq_register( BUTTON3_IRQ, params, handle_button3_interrupts );

    //semaphore to block/unblock LCD task so it only updates when a change is made
    LCDSem = OSSemCreate(1);

    OSTaskCreateExt(audio_data_task,
                  params,
                  (void *)&audio_data_task_stk[AUDIO_DATA_TASK_STACKSIZE-1],
                  AUDIO_DATA_TASK_PRIORITY,
                  AUDIO_DATA_TASK_PRIORITY,
                  audio_data_task_stk,
                  AUDIO_DATA_TASK_STACKSIZE,
                  NULL,
                  0);

    OSTaskCreateExt(LCD_task,
                  params,
                  (void *)&LCD_task_stk[LCD_TASK_STACKSIZE-1],
                  LCD_TASK_PRIORITY,
                  LCD_TASK_PRIORITY,
                  LCD_task_stk,
                  LCD_TASK_STACKSIZE,
                  NULL,
                  0);

    OSTaskCreateExt(BT_task,
              NULL,
              (void *)&BT_task_stk[BT_TASK_STACKSIZE-1],
              BT_TASK_PRIORITY,
              BT_TASK_PRIORITY,
              BT_task_stk,
              BT_TASK_STACKSIZE,
              NULL,
              0);

    OSStart();
    return 0;
}

/******************************************************************************
*                                                                             *
* License Agreement                                                           *
*                                                                             *
* Copyright (c) 2004 Altera Corporation, San Jose, California, USA.           *
* All rights reserved.                                                        *
*                                                                             *
* Permission is hereby granted, free of charge, to any person obtaining a     *
* copy of this software and associated documentation files (the "Software"),  *
* to deal in the Software without restriction, including without limitation   *
* the rights to use, copy, modify, merge, publish, distribute, sublicense,    *
* and/or sell copies of the Software, and to permit persons to whom the       *
* Software is furnished to do so, subject to the following conditions:        *
*                                                                             *
* The above copyright notice and this permission notice shall be included in  *
* all copies or substantial portions of the Software.                         *
*                                                                             *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  *
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,    *
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE *
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER      *
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING     *
* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER         *
* DEALINGS IN THE SOFTWARE.                                                   *
*                                                                             *
* This agreement shall be governed in all respects by the laws of the State   *
* of California and by the laws of the United States of America.              *
* Altera does not recommend, suggest or require that this reference design    *
* file be used in conjunction or combination with any other product.          *
******************************************************************************/

