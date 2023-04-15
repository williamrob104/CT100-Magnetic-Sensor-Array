#include "STM8S.h"

#define UART_TX GPIOD, GPIO_PIN_5
#define UART_RX GPIOD, GPIO_PIN_6
#define GAIN_A0 GPIOB, GPIO_PIN_4
#define GAIN_A1 GPIOB, GPIO_PIN_5
#define SPI_SCK GPIOC, GPIO_PIN_5
#define SPI_DIN GPIOC, GPIO_PIN_6
#define SYNC1   GPIOD, GPIO_PIN_2
#define SYNC2   GPIOA, GPIO_PIN_2
#define SYNC3   GPIOD, GPIO_PIN_3
#define SYNC4   GPIOA, GPIO_PIN_1
#define LED     GPIOC, GPIO_PIN_3

#define BAUD_RATE 9600u

#define LED_BLINK 100u  // ms

void setGain(uint8_t g)
{
	/* g = 0b00, 0b01, 0b10, 0b11 */
	if (g & 0b01) GPIO_WriteHigh(GAIN_A0); else GPIO_WriteLow(GAIN_A0);
	if (g & 0b10) GPIO_WriteHigh(GAIN_A1); else GPIO_WriteLow(GAIN_A1);
}

void setChannel(uint8_t channel_num, uint8_t sensor_num)
{
	/* channel_num = 1, 2, 3, 4
	   sensor_num  = 0 ~ 15     */
	switch (channel_num) {
		case 1: GPIO_WriteLow(SYNC1); break;
		case 2: GPIO_WriteLow(SYNC2); break;
		case 3: GPIO_WriteLow(SYNC3); break;
		case 4: GPIO_WriteLow(SYNC4); break;
	}

	SPI_SendData(sensor_num & 0x0F);
	while (SPI_GetFlagStatus(SPI_FLAG_BSY) == SET) {}

	switch (channel_num) {
		case 1: GPIO_WriteHigh(SYNC1); break;
		case 2: GPIO_WriteHigh(SYNC2); break;
		case 3: GPIO_WriteHigh(SYNC3); break;
		case 4: GPIO_WriteHigh(SYNC4); break;
	}
}

main()
{
	uint8_t cmd, cmd_u, cmd_l;
	uint8_t accept;

	// init GPIO
	GPIO_Init(GAIN_A0, GPIO_MODE_OUT_PP_LOW_SLOW);
	GPIO_Init(GAIN_A1, GPIO_MODE_OUT_PP_LOW_SLOW);
	GPIO_Init(SYNC1,   GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(SYNC2,   GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(SYNC3,   GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(SYNC4,   GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(LED,     GPIO_MODE_OUT_PP_HIGH_SLOW);

	// init SPI
	GPIO_Init(SPI_SCK, GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(SPI_DIN, GPIO_MODE_OUT_PP_HIGH_SLOW);

	SPI_Init(SPI_FIRSTBIT_MSB,
	         SPI_BAUDRATEPRESCALER_32,
			 SPI_MODE_MASTER,
			 SPI_CLOCKPOLARITY_HIGH,
			 SPI_CLOCKPHASE_1EDGE,
			 SPI_DATADIRECTION_1LINE_TX,
			 SPI_NSS_SOFT, 0x07);
	SPI_Cmd(ENABLE);

	// init UART
	GPIO_Init(UART_TX, GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(UART_RX, GPIO_MODE_IN_PU_NO_IT);

	UART1_Init(BAUD_RATE,
	           UART1_WORDLENGTH_8D,
	           UART1_STOPBITS_1,
			   UART1_PARITY_NO,
			   UART1_SYNCMODE_CLOCK_DISABLE,
			   UART1_MODE_TXRX_ENABLE);
	UART1_Cmd(ENABLE);

	// init TIM
	TIM1_TimeBaseInit(1999u, TIM1_COUNTERMODE_UP, LED_BLINK-1, 0u);
	TIM1_SelectOnePulseMode(TIM1_OPMODE_SINGLE);

	// main loop
	while (1) {
		if (TIM1_GetFlagStatus(TIM1_FLAG_UPDATE) == SET) {
			TIM1_ClearFlag(TIM1_FLAG_UPDATE);
			GPIO_WriteHigh(LED);
		}

		if (UART1_GetFlagStatus(UART1_FLAG_RXNE) == RESET)
			continue;

		cmd = UART1_ReceiveData8();
		accept = 1;

		cmd_u = cmd & 0xF0;
		cmd_l = cmd & 0x0F;

		if (cmd_u == 0xA0 && cmd_l <= 0x03)
			setGain(cmd_l);
		else if (0x10 <= cmd_u & cmd_u <= 0x40)
			setChannel(cmd_u >> 4, cmd_l);
		else
			accept = 0;

		if (accept) {
			GPIO_WriteLow(LED);
			TIM1_Cmd(ENABLE);

			while (UART1_GetFlagStatus(UART1_FLAG_TXE) == RESET) {}
			UART1_SendData8(cmd);
		}
	}
}
