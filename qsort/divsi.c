#include "stdint.h"

#define C3B(a,b,c) a##b##c
#define C3(a,b,c) C3B(a,b,c)

#define UINT_TYPE	uint32_t
#define SINT_TYPE	int32_t
#define BITS_MINUS_1	31
#define NAME_MODE	si
typedef int         word_type;

#include "divmod.h"
