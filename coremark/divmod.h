UINT_TYPE C3(udivmod,NAME_MODE,4) (UINT_TYPE, UINT_TYPE, word_type);
SINT_TYPE C3(__div,NAME_MODE,3)   (SINT_TYPE, SINT_TYPE);
SINT_TYPE C3(__mod,NAME_MODE,3)   (SINT_TYPE, SINT_TYPE);
UINT_TYPE C3(__udiv,NAME_MODE,3)  (UINT_TYPE, UINT_TYPE);
UINT_TYPE C3(__umod,NAME_MODE,3)  (UINT_TYPE, UINT_TYPE);

UINT_TYPE
C3(udivmod,NAME_MODE,4) (UINT_TYPE num, UINT_TYPE den, word_type modwanted)
{
  UINT_TYPE bit = 1;
  UINT_TYPE res = 0;

  while (den < num && bit && !(den & (1L << BITS_MINUS_1)))
    {
      den <<= 1;
      bit <<= 1;
    }
  while (bit)
    {
      if (num >= den)
	{
	  num -= den;
	  res |= bit;
	}
      bit >>= 1;
      den >>= 1;
    }
  if (modwanted)
    return num;
  return res;
}

SINT_TYPE
C3(__div,NAME_MODE,3) (SINT_TYPE a, SINT_TYPE b)
{
  word_type neg = 0;
  SINT_TYPE res;

  if (a < 0)
    {
      a = -a;
      neg = !neg;
    }

  if (b < 0)
    {
      b = -b;
      neg = !neg;
    }

  res = C3(udivmod,NAME_MODE,4) (a, b, 0);

  if (neg)
    res = -res;

  return res;
}

SINT_TYPE
C3(__mod,NAME_MODE,3) (SINT_TYPE a, SINT_TYPE b)
{
  word_type neg = 0;
  SINT_TYPE res;

  if (a < 0)
    {
      a = -a;
      neg = 1;
    }

  if (b < 0)
    b = -b;

  res = C3(udivmod,NAME_MODE,4) (a, b, 1);

  if (neg)
    res = -res;

  return res;
}

UINT_TYPE
C3(__udiv,NAME_MODE,3) (UINT_TYPE a, UINT_TYPE b)
{
  return C3(udivmod,NAME_MODE,4) (a, b, 0);
}

UINT_TYPE
C3(__umod,NAME_MODE,3) (UINT_TYPE a, UINT_TYPE b)
{
  return C3(udivmod,NAME_MODE,4) (a, b, 1);
}
