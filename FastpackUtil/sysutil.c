#include <caml/memory.h>
#include <caml/mlvalues.h>

#ifdef _WIN32
#include <windows.h>
#endif

value pid_of_handle(value handle) {
  CAMLparam1(handle);
#ifdef _WIN32
  CAMLreturn(Val_int(GetProcessId((HANDLE)Long_val(handle))));
#else
  CAMLreturn(handle);
#endif
}
