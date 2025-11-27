#include "stdint.h"

#define C3B(a,b,c) a##b##c
#define C3(a,b,c) C3B(a,b,c)

#define UINT_TYPE	uint16_t
#define SINT_TYPE	int16_t
#define BITS_MINUS_1	15
#define NAME_MODE	hi
typedef int         word_type;

#include "divmod.h"
