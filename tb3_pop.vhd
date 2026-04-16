-- TB3: pop operation coverage for non-empty lists

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.tb_utils_pkg.all;

entity project_tb_pop is
end project_tb_pop;


architecture project_tb_arch of project_tb_pop is

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
        -- STEP 1: pop on a single-element list
        --------------------------------------------------
        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(1, 8))
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(13, 2)
        );

        check_ram_count(RAM, 1, "STEP 1 preload count");
        check_ram_value(RAM, 1, encode_task(13, 2), "STEP 1 preload RAM(1)");

        memory_control <= '1';

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
            "001101"
        );

        check_ram_count(RAM, 0, "STEP 1 count after pop on single-element list");

        report "STEP 1 OK: pop on single-element list, with o_task_id checked at DONE=1.";

        --------------------------------------------------
        -- STEP 2: pop on an N-element list
        --------------------------------------------------
        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(7, 8))
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(16, 1)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            2, encode_task(22, 1)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            3, encode_task(23, 1)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            4, encode_task(21, 2)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            5, encode_task(19, 2)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            6, encode_task(28, 3)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            7, encode_task(4, 3)
        );

        check_ram_count(RAM, 7, "STEP 2 preload count");
        check_ram_value(RAM, 1, encode_task(16, 1), "STEP 2 preload RAM(1)");
        check_ram_value(RAM, 2, encode_task(22, 1), "STEP 2 preload RAM(2)");
        check_ram_value(RAM, 3, encode_task(23, 1), "STEP 2 preload RAM(3)");
        check_ram_value(RAM, 4, encode_task(21, 2), "STEP 2 preload RAM(4)");
        check_ram_value(RAM, 5, encode_task(19, 2), "STEP 2 preload RAM(5)");
        check_ram_value(RAM, 6, encode_task(28, 3), "STEP 2 preload RAM(6)");
        check_ram_value(RAM, 7, encode_task(4, 3),  "STEP 2 preload RAM(7)");

        memory_control <= '1';

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
            6,
            "010000"
        );

        check_ram_count(RAM, 6, "STEP 2 count after first pop on N-element list");
        check_ram_value(RAM, 1, encode_task(22, 1), "STEP 2 shifted RAM(1)");
        check_ram_value(RAM, 2, encode_task(23, 1), "STEP 2 shifted RAM(2)");
        check_ram_value(RAM, 3, encode_task(21, 2), "STEP 2 shifted RAM(3)");
        check_ram_value(RAM, 4, encode_task(19, 2), "STEP 2 shifted RAM(4)");
        check_ram_value(RAM, 5, encode_task(28, 3), "STEP 2 shifted RAM(5)");
        check_ram_value(RAM, 6, encode_task(4, 3),  "STEP 2 shifted RAM(6)");

        report "STEP 2 OK: pop on N-element list, with full left shift check.";

        --------------------------------------------------
        -- STEP 3A: second pop on the resulting non-empty list
        --------------------------------------------------
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
            5,
            "010110"
        );

        check_ram_count(RAM, 5, "STEP 3A count after second pop on non-empty list");
        check_ram_value(RAM, 1, encode_task(23, 1), "STEP 3A shifted RAM(1)");
        check_ram_value(RAM, 2, encode_task(21, 2), "STEP 3A shifted RAM(2)");
        check_ram_value(RAM, 3, encode_task(19, 2), "STEP 3A shifted RAM(3)");
        check_ram_value(RAM, 4, encode_task(28, 3), "STEP 3A shifted RAM(4)");
        check_ram_value(RAM, 5, encode_task(4, 3),  "STEP 3A shifted RAM(5)");

        report "STEP 3A OK: repeated pop on non-empty list, with o_task_id checked again at DONE=1.";

        --------------------------------------------------
        -- STEP 3B: pop all remaining tasks and check each state
        --------------------------------------------------
        -- STEP 3B.1
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
            4,
            "010111"
        );

        check_ram_count(RAM, 4, "STEP 3B.1 count after pop");
        check_ram_value(RAM, 1, encode_task(21, 2), "STEP 3B.1 shifted RAM(1)");
        check_ram_value(RAM, 2, encode_task(19, 2), "STEP 3B.1 shifted RAM(2)");
        check_ram_value(RAM, 3, encode_task(28, 3), "STEP 3B.1 shifted RAM(3)");
        check_ram_value(RAM, 4, encode_task(4, 3),  "STEP 3B.1 shifted RAM(4)");

        report "STEP 3B.1 OK: popped task 23.";


        -- STEP 3B.2
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
            3,
            "010101"
        );

        check_ram_count(RAM, 3, "STEP 3B.2 count after pop");
        check_ram_value(RAM, 1, encode_task(19, 2), "STEP 3B.2 shifted RAM(1)");
        check_ram_value(RAM, 2, encode_task(28, 3), "STEP 3B.2 shifted RAM(2)");
        check_ram_value(RAM, 3, encode_task(4, 3),  "STEP 3B.2 shifted RAM(3)");

        report "STEP 3B.2 OK: popped task 21.";


        -- STEP 3B.3
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
            2,
            "010011"
        );

        check_ram_count(RAM, 2, "STEP 3B.3 count after pop");
        check_ram_value(RAM, 1, encode_task(28, 3), "STEP 3B.3 shifted RAM(1)");
        check_ram_value(RAM, 2, encode_task(4, 3),  "STEP 3B.3 shifted RAM(2)");

        report "STEP 3B.3 OK: popped task 19.";


        -- STEP 3B.4
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
            1,
            "011100"
        );

        check_ram_count(RAM, 1, "STEP 3B.4 count after pop");
        check_ram_value(RAM, 1, encode_task(4, 3), "STEP 3B.4 shifted RAM(1)");

        report "STEP 3B.4 OK: popped task 28.";


        -- STEP 3B.5
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
            "000100"
        );

        check_ram_count(RAM, 0, "STEP 3B.5 count after final pop");

        report "STEP 3B.5 OK: popped final task 4, list is now empty.";

        --------------------------------------------------
        -- STEP 4A: explicit pop with head priority 0
        --------------------------------------------------
        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(3, 8))
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(15, 0)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            2, encode_task(31, 2)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            3, encode_task(7, 3)
        );

        memory_control <= '1';

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
            2,
            "001111"
        );

        check_ram_count(RAM, 2, "STEP 4A count after pop with head priority 0");
        check_ram_value(RAM, 1, encode_task(31, 2), "STEP 4A shifted RAM(1)");
        check_ram_value(RAM, 2, encode_task(7, 3),  "STEP 4A shifted RAM(2)");

        report "STEP 4A OK: explicit pop with head priority 0.";

        --------------------------------------------------
        -- STEP 4B: explicit pop with head priority 3
        --------------------------------------------------
        memory_control <= '0';

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            0, std_logic_vector(to_unsigned(3, 8))
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            1, encode_task(31, 3)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            2, encode_task(6, 3)
        );

        preload_ram_value(
            tb_clk, init_o_mem_addr, init_o_mem_data, init_o_mem_en, init_o_mem_we,
            3, encode_task(9, 3)
        );

        memory_control <= '1';

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
            2,
            "011111"
        );

        check_ram_count(RAM, 2, "STEP 4B count after pop with head priority 3");
        check_ram_value(RAM, 1, encode_task(6, 3), "STEP 4B shifted RAM(1)");
        check_ram_value(RAM, 2, encode_task(9, 3), "STEP 4B shifted RAM(2)");

        report "STEP 4B OK: explicit pop with head priority 3.";

        --------------------------------------------------
        -- final result
        --------------------------------------------------
        report "=========================================";
        assert false
            report "Simulation Ended! TESTBENCH 3 PASSED (pop non-empty cases)"
            severity failure;
    end process;

end architecture;