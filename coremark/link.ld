ENTRY (_start)
__total_size = 0x7f00;
__stack_size = 0x800;
PROVIDE( _stack_size = __stack_size );
SECTIONS
{
  . = 0x0000;
  .vector :
  {
    KEEP(*(SORT_NONE(.vector)))
  }
  .text : {
    . = ALIGN(4);
    *(.text)
    *(.text.*)
    *(.rodata)
    *(.rodata*)
    . = ALIGN(4);
    _shell_command_start = .;
    KEEP (*(shellCommand))
    _shell_command_end = .;
  }
  .data : {
    *(.data)
    *(.data.*)
  }
  .bss : {
    *(.bss)
  }
  . = ALIGN(16);
  PROVIDE( _heap = .);
  . = __total_size - __stack_size;
  PROVIDE( _heap_end = . );
  . = ALIGN(4);
  . = . + __stack_size;
  PROVIDE( _stack = .);
}
