#include "STM8S.h"

#define UART_TX GPIOD, GPIO_PIN_5
#define UART_RX GPIOD, GPIO_PIN_6

#define GAIN_A0 GPIOC, GPIO_PIN_3
#define GAIN_A1 GPIOB, GPIO_PIN_4
#define WR1     GPIOC, GPIO_PIN_7
#define WR2     GPIOB, GPIO_PIN_5
#define WR3     GPIOD, GPIO_PIN_2
#define WR4     GPIOA, GPIO_PIN_3

#define SPI_SCK GPIOC, GPIO_PIN_5
#define SPI_DIN GPIOC, GPIO_PIN_6
#define SYNC1   GPIOD, GPIO_PIN_3
#define SYNC2   GPIOA, GPIO_PIN_2
#define SYNC3   GPIOD, GPIO_PIN_4
#define SYNC4   GPIOA, GPIO_PIN_1

#define LED     GPIOC, GPIO_PIN_4

#define BAUD_RATE 115200u
#define LED_BLINK 200u  // ms

void setChannel(uint8_t channel, uint8_t gain, uint8_t sensor)
{
	/* channel = 0, 1, 2, 3
	   gain    = 0x00 ~ 0x11
	   sensor  = 0 ~ 15     */
	if (gain & 0b01) GPIO_WriteHigh(GAIN_A0); else GPIO_WriteLow(GAIN_A0);
	if (gain & 0b10) GPIO_WriteHigh(GAIN_A1); else GPIO_WriteLow(GAIN_A1);

	switch (channel) {
		case 0: GPIO_WriteLow(SYNC1); GPIO_WriteLow(WR1); break;
		case 1: GPIO_WriteLow(SYNC2); GPIO_WriteLow(WR2); break;
		case 2: GPIO_WriteLow(SYNC3); GPIO_WriteLow(WR3); break;
		case 3: GPIO_WriteLow(SYNC4); GPIO_WriteLow(WR4); break;
	}

	SPI_SendData(sensor & 0x0F);

	switch (channel) {
		case 0: GPIO_WriteHigh(SYNC1); GPIO_WriteHigh(WR1); break;
		case 1: GPIO_WriteHigh(SYNC2); GPIO_WriteHigh(WR2); break;
		case 2: GPIO_WriteHigh(SYNC3); GPIO_WriteHigh(WR3); break;
		case 3: GPIO_WriteHigh(SYNC4); GPIO_WriteHigh(WR4); break;
	}
}

main()
{
	uint8_t cmd;

	// configure clock
	CLK_HSIPrescalerConfig(CLK_PRESCALER_HSIDIV1);
	CLK_PeripheralClockConfig(CLK_PERIPHERAL_I2C,    DISABLE);
	CLK_PeripheralClockConfig(CLK_PERIPHERAL_TIMER4, DISABLE);
	CLK_PeripheralClockConfig(CLK_PERIPHERAL_TIMER2, DISABLE);
	CLK_PeripheralClockConfig(CLK_PERIPHERAL_AWU,    DISABLE);
	CLK_PeripheralClockConfig(CLK_PERIPHERAL_ADC,    DISABLE);

	// init GPIO
	GPIO_Init(GAIN_A0, GPIO_MODE_OUT_PP_LOW_SLOW);
	GPIO_Init(GAIN_A1, GPIO_MODE_OUT_PP_LOW_SLOW);
	GPIO_Init(WR1,     GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(WR2,     GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(WR3,     GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(WR4,     GPIO_MODE_OUT_PP_HIGH_SLOW);

	GPIO_Init(SYNC1,   GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(SYNC2,   GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(SYNC3,   GPIO_MODE_OUT_PP_HIGH_SLOW);
	GPIO_Init(SYNC4,   GPIO_MODE_OUT_PP_HIGH_SLOW);

	GPIO_Init(LED,     GPIO_MODE_OUT_PP_HIGH_SLOW);

	// init SPI
	GPIO_Init(SPI_SCK, GPIO_MODE_OUT_PP_HIGH_FAST);
	GPIO_Init(SPI_DIN, GPIO_MODE_OUT_PP_HIGH_FAST);

	SPI_Init(SPI_FIRSTBIT_MSB,
	         SPI_BAUDRATEPRESCALER_4,
			 SPI_MODE_MASTER,
			 SPI_CLOCKPOLARITY_HIGH,
			 SPI_CLOCKPHASE_1EDGE,
			 SPI_DATADIRECTION_1LINE_TX,
			 SPI_NSS_SOFT, 0x07);
	SPI_Cmd(ENABLE);

	// init UART
	GPIO_Init(UART_TX, GPIO_MODE_OUT_PP_HIGH_FAST);
	GPIO_Init(UART_RX, GPIO_MODE_IN_PU_NO_IT);

	UART1_Init(BAUD_RATE,
	           UART1_WORDLENGTH_8D,
	           UART1_STOPBITS_1,
			   UART1_PARITY_NO,
			   UART1_SYNCMODE_CLOCK_DISABLE,
			   UART1_MODE_TXRX_ENABLE);
	UART1_Cmd(ENABLE);

	// init TIM
	TIM1_TimeBaseInit(15999u, TIM1_COUNTERMODE_UP, LED_BLINK-1, 0u);
	TIM1_SelectOnePulseMode(TIM1_OPMODE_SINGLE);
	TIM1_Cmd(ENABLE);

	// main loop
	while (1) {
		if (TIM1_GetFlagStatus(TIM1_FLAG_UPDATE) == SET) {
			TIM1_ClearFlag(TIM1_FLAG_UPDATE);
			GPIO_WriteReverse(LED);
			TIM1_Cmd(ENABLE);
		}

		if (UART1_GetFlagStatus(UART1_FLAG_RXNE) == RESET)
			continue;

		cmd = UART1_ReceiveData8();

		setChannel(cmd >> 6, (cmd >> 4) & 0b11, cmd & 0b1111);

		while (UART1_GetFlagStatus(UART1_FLAG_TXE) == RESET) {}
		UART1_SendData8(cmd);
	}
}
