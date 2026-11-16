-- TB6: reset and initialization edge cases

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.tb_utils_pkg.all;

entity project_tb_reset is
end project_tb_reset;


architecture project_tb_arch of project_tb_reset is

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
        -- initial values
        --------------------------------------------------
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);

        wait for 50 ns;

        --------------------------------------------------
        -- STEP 1: Multiple consecutive resets
        --------------------------------------------------
        -- Re-initialize the list after each reset and verify RAM(0)=0.

        -- First reset
        tb_rst <= '1';
        wait for 100 ns;
        tb_rst <= '0';
        memory_control <= '1';

        -- Wait for the post-reset init pulse to complete
        if tb_done = '1' then
            wait until falling_edge(tb_done);
        end if;

        check_ram_count(RAM, 0, "RAM(0) /= 0 after first reset");

        report "STEP 1a OK: first reset, RAM(0)=0 confirmed.";

        -- Second reset immediately, without performing any operation
        memory_control <= '0';
        tb_rst <= '1';
        wait for 60 ns;
        tb_rst <= '0';
        memory_control <= '1';

        if tb_done = '1' then
            wait until falling_edge(tb_done);
        end if;

        check_ram_count(RAM, 0, "RAM(0) /= 0 after second consecutive reset");

        report "STEP 1b OK: second consecutive reset, RAM(0)=0 confirmed.";

        -- Third reset
        memory_control <= '0';
        tb_rst <= '1';
        wait for 40 ns;
        tb_rst <= '0';
        memory_control <= '1';

        if tb_done = '1' then
            wait until falling_edge(tb_done);
        end if;

        check_ram_count(RAM, 0, "RAM(0) /= 0 after third consecutive reset");

        report "STEP 1c OK: third consecutive reset, RAM(0)=0 confirmed.";

        wait until falling_edge(tb_clk);

        --------------------------------------------------
        -- STEP 2: Reset followed immediately by an insert
        --------------------------------------------------
        -- After reset completes, the module must accept a new START without
        -- requiring any extra reset cycle.

        -- Insert task ID=5, priority=1 immediately after reset
        run_operation(
            tb_clk,
            tb_start,
            tb_op,
            tb_i_task_id,
            tb_task_priority,
            tb_done,
            RAM(0),
            tb_o_task_id,
            "10",       -- OP = insert
            "000101",   -- task_id = 5
            "01",       -- priority = 1
            1           -- expected count = 1
        );

        report "STEP 2a OK: insert immediately after reset succeeded.";

        -- Verify the task byte is stored correctly at address 1.
        -- task byte = task_id & priority = "000101" & "01" = 0x15
        check_ram_value(RAM, 1, x"15",
            "task byte at RAM(1) after immediate post-reset insert");

        report "STEP 2b OK: RAM(1) content verified after post-reset insert.";

        --------------------------------------------------
        -- STEP 3: Reset in the middle of an operation
        --------------------------------------------------
        -- Trigger reset while START is high, then verify the module
        -- re-initializes correctly and handles a fresh operation.

        -- Begin an insert operation but do NOT wait for DONE.
        -- Assert reset after a short delay instead.
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);
        wait until falling_edge(tb_clk);

        tb_op            <= "10";   -- insert
        tb_i_task_id     <= "001010"; -- id = 10
        tb_task_priority <= "00";   -- priority = 0
        tb_start         <= '1';

        -- Let the operation start for a few cycles, then reset.
        wait for CLOCK_PERIOD;

        -- Assert reset while the operation is in progress.
        tb_rst <= '1';
        tb_start <= '0';
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);
        wait for 80 ns;
        tb_rst <= '0';
        
        wait until falling_edge(tb_done);
        wait for 2 ns;
        
        check_ram_count(RAM, 0, "RAM(0) /= 0 after mid-operation reset");

        report "STEP 3a OK: reset in middle of operation, RAM(0)=0 confirmed.";

        wait until falling_edge(tb_clk);

        -- Now verify the module works correctly after the mid-operation reset.
        -- Insert task ID=7, priority=2.
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
            "000111",   -- task_id = 7
            "10",       -- priority = 2
            1
        );

        report "STEP 3b OK: post-mid-operation-reset insert succeeded.";

        -- Pop it back to confirm the module is fully functional.
        run_operation(
            tb_clk,
            tb_start,
            tb_op,
            tb_i_task_id,
            tb_task_priority,
            tb_done,
            RAM(0),
            tb_o_task_id,
            "01",       -- pop
            "000000",
            "00",
            0,
            "000111"    -- expected popped id = 7
        );

        report "STEP 3c OK: post-mid-operation-reset pop returned correct ID.";
        
        --------------------------------------------------
        -- STEP 4: Reset in the middle of a POP operation
        --------------------------------------------------
        -- Build a non-empty list, start a pop, then assert reset while the
        -- operation is in progress. After reset, RAM(0) must be back to 0
        -- and the module must be usable again.

        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(4, 8))
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(9, 0)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            2, encode_task(10, 1)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            3, encode_task(11, 2)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            4, encode_task(12, 3)
        );

        memory_control <= '1';

        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);
        wait until falling_edge(tb_clk);

        tb_op            <= "01";   -- pop
        tb_i_task_id     <= "000000";
        tb_task_priority <= "00";
        tb_start         <= '1';

        -- Let the pop start, then interrupt it.
        wait for CLOCK_PERIOD;

        tb_rst   <= '1';
        tb_start <= '0';
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);
        wait for 80 ns;
        tb_rst   <= '0';

        wait until falling_edge(tb_done);
        wait for 2 ns;

        check_ram_count(RAM, 0, "RAM(0) /= 0 after mid-pop reset");

        report "STEP 4a OK: reset during pop, RAM(0)=0 confirmed.";

        -- Verify recovery: a pop now must behave as pop on empty list.
        run_operation(
            tb_clk,
            tb_start,
            tb_op,
            tb_i_task_id,
            tb_task_priority,
            tb_done,
            RAM(0),
            tb_o_task_id,
            "01",
            "000000",
            "00",
            0,
            "000000"
        );

        report "STEP 4b OK: post-mid-pop-reset empty pop returned ID=0.";


        --------------------------------------------------
        -- STEP 5: Reset in the middle of an AGE operation
        --------------------------------------------------
        -- Build a mixed-priority list, start an age, then assert reset while
        -- the operation is in progress. After reset, RAM(0) must be 0 and
        -- the module must accept a fresh operation.

        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(5, 8))
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(13, 0)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            2, encode_task(14, 0)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            3, encode_task(15, 1)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            4, encode_task(16, 2)
        );
        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            5, encode_task(17, 3)
        );

        memory_control <= '1';

        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);
        wait until falling_edge(tb_clk);

        tb_op            <= "00";   -- age
        tb_i_task_id     <= "000000";
        tb_task_priority <= "00";
        tb_start         <= '1';

        -- Let the age start, then interrupt it.
        wait for CLOCK_PERIOD;

        tb_rst   <= '1';
        tb_start <= '0';
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);
        wait for 80 ns;
        tb_rst   <= '0';

        wait until falling_edge(tb_done);
        wait for 2 ns;

        check_ram_count(RAM, 0, "RAM(0) /= 0 after mid-age reset");

        report "STEP 5a OK: reset during age, RAM(0)=0 confirmed.";

        -- Verify recovery: a fresh insert must now behave as insert on empty.
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
            "010001",   -- task_id = 17
            "01",       -- priority = 1
            1
        );

        check_ram_value(RAM, 1, encode_task(17, 1),
            "RAM(1) after insert following mid-age reset");

        report "STEP 5b OK: post-mid-age-reset insert succeeded.";

        --------------------------------------------------
        -- final result
        --------------------------------------------------
        report "=========================================";
        assert false
            report "Simulation Ended! TESTBENCH 6 PASSED (multiple resets + reset after op + reset during op)"
            severity failure;
    end process;

end architecture;
