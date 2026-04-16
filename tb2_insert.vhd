-- TB2: insert operation coverage

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.tb_utils_pkg.all;

entity project_tb_insert is
end project_tb_insert;


architecture project_tb_arch of project_tb_insert is

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
        -- This is necessary for the testbench to work: we swap the memory
        -- signals from the component to the testbench when needed.

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
        -- STEP 1: insert into empty list
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
            "10",
            "000101",
            "10",
            1
        );

        check_ram_count(RAM, 1, "STEP 1 count after insert into empty list");
        check_ram_value(RAM, 1, encode_task(5, 2), "STEP 1 first task after insert into empty list");

        report "STEP 1 OK: insert into empty list.";

        --------------------------------------------------
        -- STEP 2: insert highest priority into non-empty list -> head
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
            "10",
            "001100",
            "00",
            2
        );

        check_ram_count(RAM, 2, "STEP 2 count after head insert");
        check_ram_value(RAM, 1, encode_task(12, 0), "STEP 2 head task after highest-priority insert");
        check_ram_value(RAM, 2, encode_task(5, 2), "STEP 2 second task after highest-priority insert");

        report "STEP 2 OK: highest-priority insert goes to head.";

        --------------------------------------------------
        -- STEP 3: insert lowest priority -> tail
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
            "10",
            "010010",
            "11",
            3
        );

        check_ram_count(RAM, 3, "STEP 3 count after tail insert");
        check_ram_value(RAM, 1, encode_task(12, 0), "STEP 3 RAM(1)");
        check_ram_value(RAM, 2, encode_task(5, 2),  "STEP 3 RAM(2)");
        check_ram_value(RAM, 3, encode_task(18, 3), "STEP 3 tail task after lowest-priority insert");

        report "STEP 3 OK: lowest-priority insert goes to tail.";

        --------------------------------------------------
        -- STEP 4: insert intermediate priority -> ordered placement
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
            "10",
            "001001",
            "01",
            4
        );

        check_ram_count(RAM, 4, "STEP 4 count after intermediate insert");
        check_ram_value(RAM, 1, encode_task(12, 0), "STEP 4 RAM(1)");
        check_ram_value(RAM, 2, encode_task(9, 1),  "STEP 4 inserted intermediate-priority task");
        check_ram_value(RAM, 3, encode_task(5, 2),  "STEP 4 RAM(3)");
        check_ram_value(RAM, 4, encode_task(18, 3), "STEP 4 RAM(4)");

        report "STEP 4 OK: intermediate-priority insert keeps correct ordering.";

        --------------------------------------------------
        -- STEP 5: equal to first element priority (priority 0)
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
            "10",
            "010100",
            "00",
            5
        );

        check_ram_count(RAM, 5, "STEP 5 count after equal-first-priority insert");
        check_ram_value(RAM, 1, encode_task(12, 0), "STEP 5 first priority-0 task");
        check_ram_value(RAM, 2, encode_task(20, 0), "STEP 5 new task appended to priority-0 block");
        check_ram_value(RAM, 3, encode_task(9, 1),  "STEP 5 RAM(3)");
        check_ram_value(RAM, 4, encode_task(5, 2),  "STEP 5 RAM(4)");
        check_ram_value(RAM, 5, encode_task(18, 3), "STEP 5 RAM(5)");

        report "STEP 5 OK: equal priority to first element is inserted after existing priority-0 tasks.";

        --------------------------------------------------
        -- STEP 6: equal to last element priority (priority 3)
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
            "10",
            "010110",
            "11",
            6
        );

        check_ram_count(RAM, 6, "STEP 6 count after equal-last-priority insert");
        check_ram_value(RAM, 1, encode_task(12, 0), "STEP 6 RAM(1)");
        check_ram_value(RAM, 2, encode_task(20, 0), "STEP 6 RAM(2)");
        check_ram_value(RAM, 3, encode_task(9, 1),  "STEP 6 RAM(3)");
        check_ram_value(RAM, 4, encode_task(5, 2),  "STEP 6 RAM(4)");
        check_ram_value(RAM, 5, encode_task(18, 3), "STEP 6 first priority-3 task");
        check_ram_value(RAM, 6, encode_task(22, 3), "STEP 6 new task appended to priority-3 block");

        report "STEP 6 OK: equal priority to last element is inserted at the end of the priority-3 block.";

        --------------------------------------------------
        -- STEP 7: FIFO behavior for equal priority (first insertion)
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
            "10",
            "011001",
            "01",
            7
        );

        check_ram_count(RAM, 7, "STEP 7 count after first FIFO-equal insert");
        check_ram_value(RAM, 1, encode_task(12, 0), "STEP 7 RAM(1)");
        check_ram_value(RAM, 2, encode_task(20, 0), "STEP 7 RAM(2)");
        check_ram_value(RAM, 3, encode_task(9, 1),  "STEP 7 first priority-1 task");
        check_ram_value(RAM, 4, encode_task(25, 1), "STEP 7 second priority-1 task");
        check_ram_value(RAM, 5, encode_task(5, 2),  "STEP 7 RAM(5)");
        check_ram_value(RAM, 6, encode_task(18, 3), "STEP 7 RAM(6)");
        check_ram_value(RAM, 7, encode_task(22, 3), "STEP 7 RAM(7)");

        report "STEP 7 OK: first equal-priority FIFO insert is placed after the existing priority-1 task.";

        --------------------------------------------------
        -- STEP 8: FIFO behavior for equal priority (second insertion)
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
            "10",
            "010011",
            "01",
            8
        );

        check_ram_count(RAM, 8, "STEP 8 count after second FIFO-equal insert");
        check_ram_value(RAM, 1, encode_task(12, 0), "STEP 8 RAM(1)");
        check_ram_value(RAM, 2, encode_task(20, 0), "STEP 8 RAM(2)");
        check_ram_value(RAM, 3, encode_task(9, 1),  "STEP 8 priority-1 element 1");
        check_ram_value(RAM, 4, encode_task(25, 1), "STEP 8 priority-1 element 2");
        check_ram_value(RAM, 5, encode_task(19, 1), "STEP 8 priority-1 element 3");
        check_ram_value(RAM, 6, encode_task(5, 2),  "STEP 8 RAM(6)");
        check_ram_value(RAM, 7, encode_task(18, 3), "STEP 8 RAM(7)");
        check_ram_value(RAM, 8, encode_task(22, 3), "STEP 8 RAM(8)");

        report "STEP 8 OK: second equal-priority FIFO insert is placed after the full existing priority-1 block.";

        --------------------------------------------------
        -- STEP 9: longer sequence stress, equal priority 2 append
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
            "10",
            "000111",
            "10",
            9
        );

        check_ram_count(RAM, 9, "STEP 9 count after longer-sequence insert");
        check_ram_value(RAM, 1, encode_task(12, 0), "STEP 9 RAM(1)");
        check_ram_value(RAM, 2, encode_task(20, 0), "STEP 9 RAM(2)");
        check_ram_value(RAM, 3, encode_task(9, 1),  "STEP 9 RAM(3)");
        check_ram_value(RAM, 4, encode_task(25, 1), "STEP 9 RAM(4)");
        check_ram_value(RAM, 5, encode_task(19, 1), "STEP 9 RAM(5)");
        check_ram_value(RAM, 6, encode_task(5, 2),  "STEP 9 first priority-2 task");
        check_ram_value(RAM, 7, encode_task(7, 2),  "STEP 9 second priority-2 task");
        check_ram_value(RAM, 8, encode_task(18, 3), "STEP 9 RAM(8)");
        check_ram_value(RAM, 9, encode_task(22, 3), "STEP 9 RAM(9)");

        report "STEP 9 OK: longer sequence still preserves ordered insertion and FIFO in the priority-2 block.";

        --------------------------------------------------
        -- STEP 10: longer sequence stress, another head-priority append
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
            "10",
            "011111",
            "00",
            10
        );

        check_ram_count(RAM, 10, "STEP 10 count after final longer-sequence insert");
        check_ram_value(RAM, 1,  encode_task(12, 0), "STEP 10 priority-0 element 1");
        check_ram_value(RAM, 2,  encode_task(20, 0), "STEP 10 priority-0 element 2");
        check_ram_value(RAM, 3,  encode_task(31, 0), "STEP 10 priority-0 element 3");
        check_ram_value(RAM, 4,  encode_task(9, 1),  "STEP 10 RAM(4)");
        check_ram_value(RAM, 5,  encode_task(25, 1), "STEP 10 RAM(5)");
        check_ram_value(RAM, 6,  encode_task(19, 1), "STEP 10 RAM(6)");
        check_ram_value(RAM, 7,  encode_task(5, 2),  "STEP 10 RAM(7)");
        check_ram_value(RAM, 8,  encode_task(7, 2),  "STEP 10 RAM(8)");
        check_ram_value(RAM, 9,  encode_task(18, 3), "STEP 10 RAM(9)");
        check_ram_value(RAM, 10, encode_task(22, 3), "STEP 10 RAM(10)");

        report "STEP 10 OK: final longer insertion sequence preserves ordering and append-at-equal behavior.";

        --------------------------------------------------
        -- final result
        --------------------------------------------------
        report "=========================================";
        assert false
            report "Simulation Ended! TESTBENCH 2 PASSED (insert cases)"
            severity failure;
    end process;

end architecture;