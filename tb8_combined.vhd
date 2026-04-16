-- TB8: combined operation sequences coverage

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.tb_utils_pkg.all;

entity project_tb_combined_sequences is
end project_tb_combined_sequences;


architecture project_tb_arch of project_tb_combined_sequences is

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
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);

        wait for 50 ns;

        --------------------------------------------------
        -- reset phase
        --------------------------------------------------
        tb_rst <= '1';
        wait for 100 ns;

        assert (tb_done = '1') or (tb_done = '0' and RAM(0) = x"00")
            report "TEST FAILED: invalid condition during/post reset"
            severity failure;

        tb_rst <= '0';
        memory_control <= '1';

        if tb_done = '1' then
            wait until falling_edge(tb_done);
        end if;

        assert RAM(0) = x"00"
            report "TEST FAILED: RAM(0) /= 0 after post-reset initialization"
            severity failure;

        wait until falling_edge(tb_clk);


        --------------------------------------------------
        -- STEP 1: Insert x N -> Pop x N
        --------------------------------------------------

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "001010", "10", 1);
        check_ram_count(RAM, 1, "STEP 1.1 count");
        check_ram_value(RAM, 1, encode_task(10, 2), "STEP 1.1 RAM(1)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "001011", "00", 2);
        check_ram_count(RAM, 2, "STEP 1.2 count");
        check_ram_value(RAM, 1, encode_task(11, 0), "STEP 1.2 RAM(1)");
        check_ram_value(RAM, 2, encode_task(10, 2), "STEP 1.2 RAM(2)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "001100", "01", 3);
        check_ram_count(RAM, 3, "STEP 1.3 count");
        check_ram_value(RAM, 1, encode_task(11, 0), "STEP 1.3 RAM(1)");
        check_ram_value(RAM, 2, encode_task(12, 1), "STEP 1.3 RAM(2)");
        check_ram_value(RAM, 3, encode_task(10, 2), "STEP 1.3 RAM(3)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "001101", "01", 4);
        check_ram_count(RAM, 4, "STEP 1.4 count");
        check_ram_value(RAM, 1, encode_task(11, 0), "STEP 1.4 RAM(1)");
        check_ram_value(RAM, 2, encode_task(12, 1), "STEP 1.4 RAM(2)");
        check_ram_value(RAM, 3, encode_task(13, 1), "STEP 1.4 RAM(3)");
        check_ram_value(RAM, 4, encode_task(10, 2), "STEP 1.4 RAM(4)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "001110", "11", 5);
        check_ram_count(RAM, 5, "STEP 1.5 count");
        check_ram_value(RAM, 1, encode_task(11, 0), "STEP 1.5 RAM(1)");
        check_ram_value(RAM, 2, encode_task(12, 1), "STEP 1.5 RAM(2)");
        check_ram_value(RAM, 3, encode_task(13, 1), "STEP 1.5 RAM(3)");
        check_ram_value(RAM, 4, encode_task(10, 2), "STEP 1.5 RAM(4)");
        check_ram_value(RAM, 5, encode_task(14, 3), "STEP 1.5 RAM(5)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 4, "001011");
        check_ram_count(RAM, 4, "STEP 1.6 count");
        check_ram_value(RAM, 1, encode_task(12, 1), "STEP 1.6 RAM(1)");
        check_ram_value(RAM, 2, encode_task(13, 1), "STEP 1.6 RAM(2)");
        check_ram_value(RAM, 3, encode_task(10, 2), "STEP 1.6 RAM(3)");
        check_ram_value(RAM, 4, encode_task(14, 3), "STEP 1.6 RAM(4)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 3, "001100");
        check_ram_count(RAM, 3, "STEP 1.7 count");
        check_ram_value(RAM, 1, encode_task(13, 1), "STEP 1.7 RAM(1)");
        check_ram_value(RAM, 2, encode_task(10, 2), "STEP 1.7 RAM(2)");
        check_ram_value(RAM, 3, encode_task(14, 3), "STEP 1.7 RAM(3)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 2, "001101");
        check_ram_count(RAM, 2, "STEP 1.8 count");
        check_ram_value(RAM, 1, encode_task(10, 2), "STEP 1.8 RAM(1)");
        check_ram_value(RAM, 2, encode_task(14, 3), "STEP 1.8 RAM(2)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 1, "001010");
        check_ram_count(RAM, 1, "STEP 1.9 count");
        check_ram_value(RAM, 1, encode_task(14, 3), "STEP 1.9 RAM(1)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 0, "001110");
        check_ram_count(RAM, 0, "STEP 1.10 count");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 0, "000000");
        check_ram_count(RAM, 0, "STEP 1.11 count after pop on empty list");

        report "STEP 1 OK: Insert x N -> Pop x N, including FIFO and final empty pop.";


        --------------------------------------------------
        -- STEP 2: Insert -> Age -> Insert
        --------------------------------------------------

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "010100", "00", 1);
        check_ram_count(RAM, 1, "STEP 2.1 count");
        check_ram_value(RAM, 1, encode_task(20, 0), "STEP 2.1 RAM(1)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "00", "000000", "00", 1);
        check_ram_count(RAM, 1, "STEP 2.2 count");
        check_ram_value(RAM, 1, encode_task(20, 1), "STEP 2.2 RAM(1)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "010101", "01", 2);
        check_ram_count(RAM, 2, "STEP 2.3 count");
        check_ram_value(RAM, 1, encode_task(20, 1), "STEP 2.3 RAM(1)");
        check_ram_value(RAM, 2, encode_task(21, 1), "STEP 2.3 RAM(2)");

        report "STEP 2 OK: insert after age uses the updated priority values.";


        --------------------------------------------------
        -- STEP 3: Insert -> repeated Age -> Pop
        --------------------------------------------------

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "11", "000000", "00", 0);
        check_ram_count(RAM, 0, "STEP 3.0 count after clear");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "010110", "00", 1);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "010111", "10", 2);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "011000", "11", 3);

        check_ram_count(RAM, 3, "STEP 3.1 count after inserts");
        check_ram_value(RAM, 1, encode_task(22, 0), "STEP 3.1 RAM(1)");
        check_ram_value(RAM, 2, encode_task(23, 2), "STEP 3.1 RAM(2)");
        check_ram_value(RAM, 3, encode_task(24, 3), "STEP 3.1 RAM(3)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "00", "000000", "00", 3);
        check_ram_value(RAM, 1, encode_task(22, 1), "STEP 3.2 RAM(1)");
        check_ram_value(RAM, 2, encode_task(23, 3), "STEP 3.2 RAM(2)");
        check_ram_value(RAM, 3, encode_task(24, 3), "STEP 3.2 RAM(3)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "00", "000000", "00", 3);
        check_ram_value(RAM, 1, encode_task(22, 2), "STEP 3.3 RAM(1)");
        check_ram_value(RAM, 2, encode_task(23, 3), "STEP 3.3 RAM(2)");
        check_ram_value(RAM, 3, encode_task(24, 3), "STEP 3.3 RAM(3)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "00", "000000", "00", 3);
        check_ram_value(RAM, 1, encode_task(22, 3), "STEP 3.4 RAM(1)");
        check_ram_value(RAM, 2, encode_task(23, 3), "STEP 3.4 RAM(2)");
        check_ram_value(RAM, 3, encode_task(24, 3), "STEP 3.4 RAM(3)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 2, "010110");
        check_ram_count(RAM, 2, "STEP 3.5 count after pop");
        check_ram_value(RAM, 1, encode_task(23, 3), "STEP 3.5 RAM(1)");
        check_ram_value(RAM, 2, encode_task(24, 3), "STEP 3.5 RAM(2)");

        report "STEP 3 OK: repeated age saturates priorities and pop preserves resulting order.";


        --------------------------------------------------
        -- STEP 4: Clear -> Insert -> Pop
        --------------------------------------------------

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "11", "000000", "00", 0);
        check_ram_count(RAM, 0, "STEP 4.1 count after clear");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "011001", "10", 1);
        check_ram_count(RAM, 1, "STEP 4.2 count after insert");
        check_ram_value(RAM, 1, encode_task(25, 2), "STEP 4.2 RAM(1)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 0, "011001");
        check_ram_count(RAM, 0, "STEP 4.3 count after pop");

        report "STEP 4 OK: clear makes the next insert behave as insertion on an empty list.";


        --------------------------------------------------
        -- STEP 5: FIFO with multiple equal-priority inserts and repeated pops
        --------------------------------------------------

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "011010", "01", 1);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "011011", "01", 2);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "011100", "01", 3);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "011101", "00", 4);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "011110", "11", 5);

        check_ram_count(RAM, 5, "STEP 5.1 count after inserts");
        check_ram_value(RAM, 1, encode_task(29, 0), "STEP 5.1 RAM(1)");
        check_ram_value(RAM, 2, encode_task(26, 1), "STEP 5.1 RAM(2)");
        check_ram_value(RAM, 3, encode_task(27, 1), "STEP 5.1 RAM(3)");
        check_ram_value(RAM, 4, encode_task(28, 1), "STEP 5.1 RAM(4)");
        check_ram_value(RAM, 5, encode_task(30, 3), "STEP 5.1 RAM(5)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 4, "011101");
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 3, "011010");
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 2, "011011");
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 1, "011100");
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 0, "011110");

        check_ram_count(RAM, 0, "STEP 5.2 final count");

        report "STEP 5 OK: repeated pops preserve FIFO order among equal-priority inserted tasks.";

                
        --------------------------------------------------
        -- STEP 6: repeated Age -> Insert priority 3
        --------------------------------------------------

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "011111", "00", 1);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "100000", "10", 2);

        check_ram_count(RAM, 2, "STEP 6.1 count after inserts");
        check_ram_value(RAM, 1, encode_task(31, 0), "STEP 6.1 RAM(1)");
        check_ram_value(RAM, 2, encode_task(32, 2), "STEP 6.1 RAM(2)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "00", "000000", "00", 2);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "00", "000000", "00", 2);
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "00", "000000", "00", 2);

        check_ram_count(RAM, 2, "STEP 6.2 count after repeated age");
        check_ram_value(RAM, 1, encode_task(31, 3), "STEP 6.2 RAM(1)");
        check_ram_value(RAM, 2, encode_task(32, 3), "STEP 6.2 RAM(2)");

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "100001", "11", 3);

        check_ram_count(RAM, 3, "STEP 6.3 count after priority-3 insert into saturated list");
        check_ram_value(RAM, 1, encode_task(31, 3), "STEP 6.3 RAM(1)");
        check_ram_value(RAM, 2, encode_task(32, 3), "STEP 6.3 RAM(2)");
        check_ram_value(RAM, 3, encode_task(33, 3), "STEP 6.3 RAM(3)");

        report "STEP 6 OK: insert after full saturation appends to the priority-3 block.";


        --------------------------------------------------
        -- final result
        --------------------------------------------------

        report "=========================================";
        assert false
            report "Simulation Ended! TESTBENCH 8 PASSED (combined sequences)"
            severity failure;
    end process;

end architecture;