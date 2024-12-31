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

module IDE(
    input [23:12] addr,
    input [3:0] din,
    input rw,
    input ds_n,
    input as_n,
    input clk,
    input ide_access,
    input ide_enable,
    output reg ide_enabled,
    input reset_n,
    input [1:0] z2_state,
    output reg [3:0] dout,
    output idecs1_n,
    output idecs2_n,
    output reg ior_n,
    output reg iow_n,
    output [1:0] rom_bank,
    output ide_romen,
    output reg otherram_en,
    output reg enable_maprom,
    output idereg_access,
    output reg dtack
    );

`include "globalparams.vh"

reg [1:0] rom_bankSel;

assign rom_bank = (ide_enabled) ? rom_bankSel : {1'b0,addr[16]};

assign idecs1_n = !(ide_access && addr[13:12] == 2'b01 && addr[16:15] == 2'b00) || !ide_enabled;
assign idecs2_n = !(ide_access && addr[13:12] == 2'b10 && addr[16:15] == 2'b00) || !ide_enabled;

assign ide_romen = !(ide_access && (!ide_enabled || addr[16]));

assign idereg_access = ide_access && ide_enabled && addr[16:15] == 2'b01;

reg [2:0] ds_delay;

always @(posedge clk or posedge ds_n)
begin
  if (ds_n) begin
    ds_delay <= 'b0;
    iow_n <= 1;
    ior_n <= 1;
  end else begin
    if (ds_delay < 3'd7) begin
      ds_delay <= ds_delay + 1;
    end

    // IOR assertion delayed by ~100ns after as_n to meet t1 address Setup time for IOR
    if (rw && !as_n && ds_delay > 3'd4)
      ior_n <= 0;

    // IOW asserted in S4, deasserted ~120ns later so that t4 IOW data hold time is met
    if (!rw && !as_n) begin
      if (ds_delay < 3'd5) begin
        iow_n <= 0;
      end else begin
        iow_n <= 1;
      end
    end
  end
end

always @(posedge clk or negedge reset_n) begin
  if (!reset_n) begin
    ide_enabled <= 0;
    rom_bankSel <= 0;
    otherram_en <= 0;
    dtack       <= 0;
  end else begin
    if (ide_enable && !rw && ide_access) ide_enabled <= 1;

    if (idereg_access && z2_state == Z2_DATA && !dtack) begin
      dtack <= 1;

      if (idereg_access) begin
        if (rw) begin
          dout[3:0] <= {rom_bankSel[1:0],otherram_en,enable_maprom};
        end else begin
          rom_bankSel   <= din[3:2];
          otherram_en   <= din[1];
          enable_maprom <= din[0];
        end
      end
    end else begin
      dtack <= 0;
    end
  end
end

endmodule
