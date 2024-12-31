// SPDX-License-Identifier: GPL-2.0-only
/* This file is part of maprom
 * Copyright (C) 2023 Matthew Harlum <matt@harlum.net>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#include <exec/execbase.h>
#include <proto/exec.h>
#include <proto/expansion.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>
#include <proto/dos.h>
#include <dos/dos.h>
#include "../include/board.h"

#define MAPROM_EN  1<<4

#define ROM_256K 0x040000
#define ROM_512K 0x080000

char *ks_filename;
char *ext_filename;

bool write_ext_rom;
bool disable_maprom;

struct Library *DosBase;
struct ExecBase *SysBase;
struct ExpansionBase *ExpansionBase = NULL;


void cleanup();
bool copyRom(char *, APTR, ULONG);
int getArgs(int, char* []);
ULONG getFileSize(char *);

int main(int argc, char *argv[])
{
  SysBase = *((struct ExecBase **)4UL);
  DosBase = OpenLibrary("dos.library",0);

  if (DosBase == NULL) {
    return 0;
  }
  printf("RIDE MapROM tool\n");
  if (getArgs(argc,argv))
  {
    ULONG romSize = 0;
    APTR destination = (void *)0xF80000;

    if ((ExpansionBase = (struct ExpansionBase *)OpenLibrary("expansion.library",0)) != NULL) {
      struct ConfigDev *cd = NULL;
      if (cd = (struct ConfigDev*)FindConfigDev(NULL,MANUF_ID,PROD_ID_IDE)) {
        UBYTE *control_register = cd->cd_BoardAddr + 0x8000;
        if (disable_maprom == true) {
          *control_register &= ~(MAPROM_EN);
          printf("MapROM disabled.\n");
        } else {
          printf("Programming kick file %s\n",ks_filename);
          if ((romSize = getFileSize(ks_filename)) == 0) {
            goto fatal;
          };
          if (romSize == ROM_256K || romSize == ROM_512K) {

            if (copyRom(ks_filename, destination, romSize) != true) {
              printf("Failed to write kickstart rom.\n");
              goto fatal;
            }

            *control_register |= MAPROM_EN;

          } else {
            printf("Bad rom size, 256K/512K ROM required.\n");
            goto fatal;
          }

          if (write_ext_rom) {
            destination = (void *)0xF00000;
            printf("Programming extended rom %s\n",ext_filename);
            if ((romSize = getFileSize(ext_filename)) == 0) {
              goto fatal;
            };

            if (copyRom(ext_filename, destination, romSize) != true) {
              printf("Failed to write extended rom.\n");
              goto fatal;
            }; 
          }

        }
      } else {
        printf("Couldn't find board with Manufacturer/Prod ID of %d:%d\n",MANUF_ID,PROD_ID_IDE);
        goto fatal;
      }
    } else {
      printf("Couldn't open Expansion.library.\n");
      goto fatal;
    }
  } else {
    goto fatal;
  }
  printf("Reboot for changes to take effect.\n");
  cleanup();
  return (0);

fatal:
  cleanup();
  return (5);
}

int getArgs(int argc, char *argv[]) {
  disable_maprom = false;

  for (int i=1; i<argc; i++) {
    if (argv[i][0] == '-') {
      switch(argv[i][1]) {
        case 'D':
        case 'd':
          disable_maprom = true;
          break;
        case 'K':
        case 'k':
          if (i+1 < argc) {
            ks_filename = argv[i+1];
            i++;
          }
          break;
        case 'E':
        case 'e':
          if (i+1 < argc) {
            ext_filename = argv[i+1];
            i++;
            write_ext_rom = true;
          }
          break;
      }
    }
  }
  if (ks_filename != NULL || disable_maprom == true) {
    return 1;
  } else {
    printf("Usage: %s -k <kickstart> [-e <extended rom>] [-d]\n",argv[0]);
    return 0;
  }
}

ULONG getFileSize(char *filename) {
  BPTR fileLock;
  ULONG fileSize = 0;
  struct FileInfoBlock *FIB;
  FIB = (struct FileInfoBlock *)AllocMem(sizeof(struct FileInfoBlock),MEMF_CLEAR);
  if ((fileLock = Lock(filename,ACCESS_READ)) != 0) {
    if (Examine(fileLock,FIB)) {
      fileSize = FIB->fib_Size;
    }
  } else {
    printf("Error opening %s\n",filename);
  }
  if (fileLock) UnLock(fileLock);
  if (FIB) FreeMem(FIB,sizeof(struct FileInfoBlock));
  return (fileSize);
}

bool copyRom(char *filename, APTR destination, ULONG romSize) {
  BPTR fh = Open(filename,MODE_OLDFILE);
  bool success = 0;
  if (fh) {
    APTR buffer = AllocMem(romSize, 0);
    if (buffer) {
      Read(fh,buffer,romSize);

      printf("Copying... ");
      CopyMem(buffer,destination,romSize);

      // Double-up 256K Kickstart ROMs
      if ((ULONG)destination == 0xF80000 && romSize == ROM_256K) {
        destination += romSize;
        CopyMem(buffer,destination,romSize);
      }

      printf("Done!\n");
      FreeMem(buffer,romSize);
      success = true;
    } else {
      printf("Unable to allocate memory.\n");
    }
  }
  if (fh) Close(fh);
  return (success);
}

void cleanup() {
  if (ExpansionBase) CloseLibrary((struct Library *)ExpansionBase);
  if (DosBase) CloseLibrary((struct Library *)DosBase);
}
