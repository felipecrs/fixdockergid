#include <unistd.h>
#include <stdlib.h>

#include "fixdockergid.h" 

int main() {
    setuid(0);
    system(fixdockergid_sh);
}
