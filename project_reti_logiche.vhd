library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_task_id : in std_logic_vector(5 downto 0);
        i_task_priority : in std_logic_vector(1 downto 0);
        i_op : in std_logic_vector(1 downto 0);
        o_done : out std_logic;
        o_task_id : out std_logic_vector(5 downto 0);
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we : out std_logic;
        o_mem_en : out std_logic
    );
end project_reti_logiche;

architecture rtl of project_reti_logiche is
    i_rst = '1';
    if(i_rst = '1') then
        o_done <= '0';
        o_task_id <= "000000";
        o_mem_addr <= "0000000000000000";
        o_mem_data <= "00000000";
        o_mem_we <= '0';
        o_mem_en <= '0';
    end if;


end architecture rtl;