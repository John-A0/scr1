
ARCH_lowercase = $(shell echo $(ARCH) | tr A-Z a-z)

# Lab 3, variant 5: only the "xor" test is built
rv32_isa_tests += isa/rv32ui/xor.S
