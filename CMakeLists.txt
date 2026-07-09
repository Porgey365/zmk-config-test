# Out-of-tree drivers vendored in this config repo. Picked up by ZMK because a
# zephyr/module.yml exists at the repo root (build adds -DZMK_EXTRA_MODULES).
if(CONFIG_APDS9960C)
  add_subdirectory(drivers/sensor/apds9960c)
endif()
