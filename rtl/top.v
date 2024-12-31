`timescale 1ns / 1ps
/*
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
module RIDE(
    inout [15:12] DBUS,
    input [23:1] ADDR,
    input BERR_n,
    input UDS_n,
    input LDS_n,
    input RW,
    input AS_n,
    input RESET_n,
    input ECLK,
    input CFGIN_n,
    output DTACK_n,
    inout OVR_n,
    output CFGOUT_n,
// IDE stuff
    input IDE_ENABLE,
    output IOR_n,
    output IOW_n,
    output IDECS1_n,
    output IDECS2_n,
    output IDEBUF_OE,
    output IDE_ROMEN,
    output [1:0] ROM_BANK,
// SDRAM Stuff
    input [1:0] RAM_SIZE,
    input MEMCLK,
    output MEMW_n,
    output RAS_n,
    output CAS_n,
    output CKE,
    output DQML,
    output DQMH,
    output RAMCS_n,
    output [11:0] MA,
    output [1:0] BA,
    output RAMOE_n
    );

`include "globalparams.vh"

wire autoconfig_cycle;
wire [3:0] autoconfig_dout;
wire ram_dtack;
wire autoconf_dtack;
wire idereg_dtack;

reg ovr_detect;

wire ram_access;
wire ide_access;
wire idereg_access;
wire otherram_en;
wire [3:0] ideregister_dout;
wire ide_enabled;
wire ovl;
wire enable_maprom;
wire ram_ready;
wire bonus_en;

reg [1:0] uds_n_sync;
reg [1:0] lds_n_sync;
reg [2:0] as_n_sync;
reg [1:0] rw_sync;

// Detect if OVR has been connected
// A weak pull-down resistor will pull this signal low if disconnected.
//
// IDE & 8M Fast RAM can operate without OVR
// But A0 & C0 RAM can't
always @(posedge RESET_n) begin
  ovr_detect <= OVR_n;
end

always @(posedge MEMCLK or negedge RESET_n) begin
  if (!RESET_n) begin
    uds_n_sync <= 2'b11;
    lds_n_sync <= 2'b11;
    as_n_sync  <= 3'b111;
    rw_sync    <= 2'b11;
  end else begin
    uds_n_sync[1:0] <= {uds_n_sync[0],UDS_n};
    lds_n_sync[1:0] <= {lds_n_sync[0],LDS_n};
    as_n_sync[2:0]  <= {as_n_sync[1:0],AS_n};
    rw_sync         <= {rw_sync[0],RW};
  end
end

reg [1:0] z2_state;

always @(posedge MEMCLK or negedge RESET_n) begin
  if (!RESET_n) begin
    z2_state <= Z2_IDLE;
  end else begin
    case (z2_state)
      Z2_IDLE:
        begin
          if (~as_n_sync[1] && (ram_access || autoconfig_cycle || idereg_access)) begin
            z2_state <= Z2_START;
          end
        end
      Z2_START:
        begin
          if (!uds_n_sync[1] || !lds_n_sync[1]) begin
            z2_state <= Z2_DATA;
          end
        end
      Z2_DATA:
        begin
          if (ram_dtack || autoconf_dtack || idereg_dtack) begin
            z2_state <= Z2_END;
          end
        end
      Z2_END:
        if (as_n_sync[1]) begin
          z2_state <= Z2_IDLE;
        end
    endcase
  end
end

Autoconfig AUTOCONFIG (
  .addr (ADDR),
  .as_n (as_n_sync[1]),
  .rw (rw_sync[1]),
  .clk (MEMCLK),
  .din (DBUS[15:12]),
  .reset_n (RESET_n),
  .ram_access (ram_access),
  .ram_size (RAM_SIZE),
  .ovr_detect (ovr_detect),
  .bonus_en (bonus_en),
  .ide_enabled (IDE_ENABLE),
  .autoconfig_cycle (autoconfig_cycle),
  .dout (autoconfig_dout),
  .z2_state (z2_state),
  .dtack (autoconf_dtack),
  .ide_access (ide_access),
  .enable_maprom (enable_maprom),
  .cfgin_n (CFGIN_n),
  .cfgout_n (CFGOUT_n),
  .ovl (ovl)
);

// Force address to F8xxxx if ovl active for early boot overlay
wire [4:0] ram_addr_hi = (ovl) ? {4'b1111, (ADDR[19] | !ADDR[23])} : ADDR[23:19];

SDRAM SDRAM (
  .addr ({ram_addr_hi, ADDR[18:1]}),
  .z2_state (z2_state),
  .uds_n (uds_n_sync[1]),
  .lds_n (lds_n_sync[1]),
  .ram_cycle (ram_access),
  .reset_n (RESET_n),
  .rw (rw_sync[1]),
  .clk (MEMCLK),
  .cke (CKE),
  .ba (BA),
  .maddr (MA),
  .cas_n (CAS_n),
  .ras_n (RAS_n),
  .cs_n (RAMCS_n),
  .we_n (MEMW_n),
  .dqml (DQML),
  .dqmh (DQMH),
  .dtack (ram_dtack),
  .eclk (ECLK),
  .init_done (ram_ready)
);

IDE IDE (
  .addr (ADDR[23:12]),
  .din (DBUS[15:12]),
  .dout (ideregister_dout),
  .z2_state (z2_state),
  .rw (RW),
  .ds_n (uds_n_sync[1]),
  .as_n (as_n_sync[1]),
  .clk (MEMCLK),
  .idecs1_n (IDECS1_n),
  .idecs2_n (IDECS2_n),
  .ide_access (ide_access),
  .ide_enable (IDE_ENABLE),
  .ide_enabled (ide_enabled),
  .reset_n (RESET_n),
  .iow_n (IOW_n),
  .ior_n (IOR_n),
  .rom_bank (ROM_BANK),
  .ide_romen (IDE_ROMEN),
  .idereg_access (idereg_access),
  .otherram_en (otherram_en),
  .enable_maprom (enable_maprom),
  .dtack (idereg_dtack)
);

assign bonus_en = otherram_en && ovr_detect;

wire buf_en = (!UDS_n || !LDS_n || !RW);

assign RAMOE_n = !(ram_access && RESET_n && buf_en);

assign IDEBUF_OE = !(ide_access && ide_enabled && ADDR[16:15] == 2'b00 && buf_en);

wire [3:0] dout = (autoconfig_cycle) ? autoconfig_dout : ideregister_dout;

assign DBUS[15:12] = ((autoconfig_cycle || idereg_access) && RW && !uds_n_sync[1] && RESET_n) ? dout : 4'bZ;

assign OVR_n = (ram_access && ovr_detect) ? 1'b0 : 1'bZ;

assign DTACK_n = (ram_ready && ram_access && !AS_n && ovr_detect) ? 1'b0 : 1'bZ;


endmodule
