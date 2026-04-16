-- TB7: START/DONE handshake protocol edge cases

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.tb_utils_pkg.all;

entity project_tb_handshake is
end project_tb_handshake;


architecture project_tb_arch of project_tb_handshake is

    constant CLOCK_PERIOD : time := 20 ns;

    signal tb_clk           : std_logic := '0';
    signal tb_rst           : std_logic := '0';
    signal tb_start         : std_logic := '0';
    signal tb_done          : std_logic;
    signal tb_o_task_id     : std_logic_vector(5 downto 0);
    signal tb_task_priority : std_logic_vector(1 downto 0) := (others => '0');
    signal tb_op            : std_logic_vector(1 downto 0) := (others => '0');
    signal tb_i_task_id     : std_logic_vector(5 downto 0) := (others => '0');

    signal tb_o_mem_addr    : std_logic_vector(15 downto 0);
    signal tb_o_mem_data    : std_logic_vector(7 downto 0);
    signal tb_i_mem_data    : std_logic_vector(7 downto 0);
    signal tb_o_mem_we      : std_logic;
    signal tb_o_mem_en      : std_logic;

    signal exc_o_mem_addr   : std_logic_vector(15 downto 0);
    signal exc_o_mem_data   : std_logic_vector(7 downto 0);
    signal exc_o_mem_we     : std_logic;
    signal exc_o_mem_en     : std_logic;

    signal init_o_mem_addr  : std_logic_vector(15 downto 0) := (others => '0');
    signal init_o_mem_data  : std_logic_vector(7 downto 0)  := (others => '0');
    signal init_o_mem_we    : std_logic := '0';
    signal init_o_mem_en    : std_logic := '0';

    signal memory_control   : std_logic := '0';

    signal RAM : ram_type := (others => (others => '0'));


    component project_reti_logiche is
        port (
            i_clk           : in std_logic;
            i_rst           : in std_logic;

            i_start         : in std_logic;
            i_task_id       : in std_logic_vector(5 downto 0);
            i_task_priority : in std_logic_vector(1 downto 0);
            i_op            : in std_logic_vector(1 downto 0);

            o_done          : out std_logic;
            o_task_id       : out std_logic_vector(5 downto 0);

            o_mem_addr      : out std_logic_vector(15 downto 0);
            i_mem_data      : in std_logic_vector(7 downto 0);
            o_mem_data      : out std_logic_vector(7 downto 0);
            o_mem_we        : out std_logic;
            o_mem_en        : out std_logic
        );
    end component;


begin

    --------------------------------------------------
    -- DUT
    --------------------------------------------------

    UUT : project_reti_logiche
    port map (
        i_clk           => tb_clk,
        i_rst           => tb_rst,
        i_start         => tb_start,
        i_task_id       => tb_i_task_id,
        i_task_priority => tb_task_priority,
        i_op            => tb_op,

        o_done          => tb_done,
        o_task_id       => tb_o_task_id,

        o_mem_addr      => exc_o_mem_addr,
        i_mem_data      => tb_i_mem_data,
        o_mem_data      => exc_o_mem_data,
        o_mem_we        => exc_o_mem_we,
        o_mem_en        => exc_o_mem_en
    );


    --------------------------------------------------
    -- clock generation
    --------------------------------------------------

    tb_clk <= not tb_clk after CLOCK_PERIOD / 2;


    --------------------------------------------------
    -- RAM model
    --------------------------------------------------

    MEM : process(tb_clk)
    begin
        if rising_edge(tb_clk) then
            if tb_o_mem_en = '1' then
                if tb_o_mem_we = '1' then
                    RAM(to_integer(unsigned(tb_o_mem_addr))) <= tb_o_mem_data after 1 ns;
                    tb_i_mem_data <= tb_o_mem_data after 1 ns;
                else
                    tb_i_mem_data <= RAM(to_integer(unsigned(tb_o_mem_addr))) after 1 ns;
                end if;
            end if;
        end if;
    end process;


    --------------------------------------------------
    -- memory signal swapper
    --------------------------------------------------

    memory_signal_swapper : process(
        memory_control,
        init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
        exc_o_mem_addr, exc_o_mem_data, exc_o_mem_en, exc_o_mem_we
    )
    begin
        tb_o_mem_addr <= init_o_mem_addr;
        tb_o_mem_data <= init_o_mem_data;
        tb_o_mem_en   <= init_o_mem_en;
        tb_o_mem_we   <= init_o_mem_we;

        if memory_control = '1' then
            tb_o_mem_addr <= exc_o_mem_addr;
            tb_o_mem_data <= exc_o_mem_data;
            tb_o_mem_en   <= exc_o_mem_en;
            tb_o_mem_we   <= exc_o_mem_we;
        end if;
    end process;


    --------------------------------------------------
    -- stimulus and checks
    --------------------------------------------------

    scenario : process
    begin
        --------------------------------------------------
        -- initial values + reset
        --------------------------------------------------
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);

        wait for 50 ns;

        tb_rst <= '1';
        wait for 100 ns;
        tb_rst <= '0';
        memory_control <= '1';

        if tb_done = '1' then
            wait until falling_edge(tb_done);
        end if;

        check_ram_count(RAM, 0, "RAM(0) /= 0 after reset");

        wait until falling_edge(tb_clk);

        --------------------------------------------------
        -- STEP 1: START kept high while DONE is high
        --------------------------------------------------
        -- Keep START high after DONE rises to verify that no new operation
        -- starts until START is lowered and raised again.

        -- Insert task ID=1, priority=0
        tb_op            <= "10";
        tb_i_task_id     <= "000001";
        tb_task_priority <= "00";
        tb_start         <= '1';

        -- Wait for DONE to go high
        wait until rising_edge(tb_done);

        -- Hold START high for several clock cycles while DONE stays high.
        wait for 5 * CLOCK_PERIOD;

        -- RAM(0) must still be 1 (one task inserted, no extra operation)
        check_ram_count(RAM, 1,
            "STEP 1 - task count changed while START was held high during DONE=1");

        report "STEP 1a OK: module did not start a spurious operation while START was held high during DONE=1.";

        -- Now lower START to complete the handshake
        tb_start <= '0';
        wait until falling_edge(tb_done);
        wait until falling_edge(tb_clk);

        check_ram_count(RAM, 1,
            "STEP 1 - task count wrong after proper handshake completion");

        report "STEP 1b OK: handshake completed correctly after releasing START.";

        --------------------------------------------------
        -- STEP 2: New operation only after a new START edge
        --------------------------------------------------
        -- Verify that no spurious memory write occurs while START=0 and
        -- DONE=0, then trigger a second operation with a new rising edge.

        -- RAM(0)=1, DONE=0, START=0. Wait a few idle cycles: count must stay 1.
        wait for 3 * CLOCK_PERIOD;

        check_ram_count(RAM, 1,
            "STEP 2 - spurious operation during idle (START=0)");

        report "STEP 2a OK: no spurious operation during idle window.";

        -- Start a second operation: insert task ID=2, priority=1
        run_operation(
            tb_clk,
            tb_start,
            tb_op,
            tb_i_task_id,
            tb_task_priority,
            tb_done,
            RAM(0),
            tb_o_task_id,
            "10",
            "000010",   -- task_id = 2
            "01",       -- priority = 1
            2           -- expected count = 2
        );

        report "STEP 2b OK: second operation launched only after new START rising edge.";

        --------------------------------------------------
        -- final result
        --------------------------------------------------
        report "=========================================";
        assert false
            report "Simulation Ended! TESTBENCH 7 PASSED (handshake edge cases)"
            severity failure;
    end process;

end architecture;
