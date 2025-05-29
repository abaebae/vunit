-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.
--
-- Copyright (c) 2014-2026, Lars Asplund lars.anders.asplund@gmail.com

library ieee;
use ieee.std_logic_1164.all;

context work.vunit_context;
use work.com_pkg.net;
use work.com_pkg.receive;
use work.com_types_pkg.all;
use work.stream_master_pkg.stream_push_msg;
use work.sync_pkg.all;
use work.uart_pkg.all;
use work.vc_pkg.all;

entity uart_master is
  generic (
    uart : uart_master_t);
  port (
    tx : out std_logic := uart.p_idle_state);
end entity;

architecture a of uart_master is
begin

  main : process
    procedure uart_send(data : std_logic_vector;
                        signal tx : out std_logic;
                        baud_rate  : integer) is
      constant time_per_bit : time := (10**9 / baud_rate) * 1 ns;

      procedure send_bit(value : std_logic) is
      begin
        tx <= value;
        wait for time_per_bit;
      end procedure;

    begin
      debug(get_logger(uart.p_std_cfg), "Sending " & to_string(data));
      send_bit(not uart.p_idle_state);
      for i in 0 to data'length-1 loop
        send_bit(data(i));
      end loop;
      send_bit(uart.p_idle_state);
    end procedure;

    variable msg : msg_t;
    variable baud_rate : natural := uart.p_baud_rate;
    variable msg_type : msg_type_t;
    constant key : key_t := get_entry_key(test_runner_cleanup);
  begin
    receive(net, get_actor(uart.p_std_cfg), msg);
    msg_type := message_type(msg);

    lock(runner, key, get_logger(uart.p_std_cfg));

    handle_sync_message(net, msg_type, msg);

    if msg_type = stream_push_msg then
      uart_send(pop_std_ulogic_vector(msg), tx, baud_rate);
    elsif msg_type = uart_set_baud_rate_msg then
      baud_rate := pop(msg);
    else
      unexpected_msg_type(msg_type, uart.p_std_cfg);
    end if;

    unlock(runner, key, get_logger(uart.p_std_cfg));

  end process;

end architecture;
