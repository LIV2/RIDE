#ifndef _CONFIG_H
#define _CONFIG_H

#include <stdbool.h>
#include <stdint.h>

typedef struct Config {
    bool dryRun;
    bool verbose;
    bool mergeFastAndBonus;
    int  fastPriority;
    
} Config;

struct Config* Configure(int, char *[]);
void usage();

#endif