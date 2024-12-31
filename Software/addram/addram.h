#ifndef _ADDRAM_H
#define _ADDRAM_H

#include "exec/types.h"
#include "config.h"

// Compiler warning fixes
#ifndef CacheClearE
// Silence the "implicit declaration of function" warning for this...
void CacheClearE(APTR,ULONG,ULONG);
#endif
#undef FindConfigDev
// NDK 1.3 definition of FindConfigDev is incorrect which causes "makes pointer from integer without a cast" warning
struct ConfigDev* FindConfigDev(struct ConfigDev*, LONG, LONG);

// End fixes
#define BOARDSTRING "GottaGoFast!!!\0"

#define BONUSRAM_EN 0x20

#define BONUSRAM_START 0xA00000
#define BONUSRAM_END   0xBF0000

void enableBonusRam();
void disableBonusRam();
ULONG sizeBonusRam(Config *);
void fixPriorities(char *, Config *);
bool getArgs(int, char*[]);
bool addBonusRam(ULONG, char*, struct Config*);

#endif