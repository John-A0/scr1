
ARCH_lowercase = $(shell echo $(ARCH) | tr A-Z a-z)

# Lab 2, variant 5: only the "instruction address misaligned" test is built
rv32_isa_tests += isa/rv32mi/ma_fetch.S
