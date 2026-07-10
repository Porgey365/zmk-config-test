/*
 * One-shot boot diagnostic: read the APDS9960's registers directly over I2C and
 * log them, independent of the stock driver (which aborts on the unexpected
 * chip id). Distinguishes a valid-but-unlisted chip id from a bad I2C read.
 *
 * SPDX-License-Identifier: MIT
 */

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/init.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(apds_probe, LOG_LEVEL_INF);

#define APDS_NODE DT_NODELABEL(apds9960)

static int apds_probe(void)
{
	const struct device *bus = DEVICE_DT_GET(DT_BUS(APDS_NODE));
	const uint16_t addr = DT_REG_ADDR(APDS_NODE);

	if (!device_is_ready(bus)) {
		LOG_ERR("APDS probe: I2C bus %s not ready",
			bus ? bus->name : "?");
		return 0;
	}

	LOG_INF("APDS probe: bus=%s addr=0x%02x", bus->name, addr);

	/* Read the ID register (0x92) several times to check for stability. */
	for (int i = 0; i < 5; i++) {
		uint8_t id = 0xff;
		int rc = i2c_reg_read_byte(bus, addr, 0x92, &id);

		LOG_INF("APDS probe: ID(0x92) read #%d -> rc=%d val=0x%02x",
			i, rc, id);
		k_msleep(20);
	}

	/* Dump the ENABLE/config/ID register window for a fingerprint. */
	for (uint8_t reg = 0x80; reg <= 0x9f; reg++) {
		uint8_t v = 0xff;
		int rc = i2c_reg_read_byte(bus, addr, reg, &v);

		LOG_INF("APDS probe: reg 0x%02x = 0x%02x (rc=%d)", reg, v, rc);
	}

	return 0;
}

SYS_INIT(apds_probe, APPLICATION, 90);
