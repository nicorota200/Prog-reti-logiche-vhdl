-- TB9: near-maximum-capacity stress test
--
-- Purpose of this testbench:
-- 1. Build a long valid list through real INSERT operations, close to the 63-task limit.
-- 2. Check selected boundary cells to catch off-by-one and addressing bugs.
-- 3. POP several tasks from the long list and verify returned IDs and left shifts.
-- 4. INSERT again after POPs to verify that freed positions are reused correctly.
-- 5. AGE the long list once to stress a long update pass over memory.
--
-- Design choice:
-- This TB does NOT check every RAM position after every single operation.
-- Instead, it checks:
-- - the count in RAM(0)
-- - selected beginning / middle / end positions
-- This keeps the TB readable while still stressing the component near the boundary.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.tb_utils_pkg.all;

entity project_tb_stress_near_full is
end project_tb_stress_near_full;


architecture project_tb_arch of project_tb_stress_near_full is

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

        variable j_int       : integer;
        variable perm_int    : integer;
        variable task_id_int : integer;
        variable prio_int    : integer;

    begin
        --------------------------------------------------
        -- initial values
        --------------------------------------------------
        clear_inputs(tb_start, tb_op, tb_i_task_id, tb_task_priority);

        wait for 50 ns;

        --------------------------------------------------
        -- reset and post-reset initialization
        --------------------------------------------------
        tb_rst <= '1';
        wait for 100 ns;
        tb_rst <= '0';
        memory_control <= '1';

        -- After reset, the DUT must reinitialize the list by writing RAM(0)=0.
        wait until falling_edge(tb_done);
        wait for 2 ns;

        check_ram_count(RAM, 0, "RAM(0) /= 0 after reset initialization");

        report "RESET OK: DUT initialized RAM(0)=0 and is ready for the stress sequence.";


                --------------------------------------------------
        -- STEP 1: Build a near-full list with 60 INSERT operations
        --
        -- New strategy:
        -- Use ONE single for loop and insert tasks in this priority order:
        --   priority 2, then priority 0, then priority 1, then priority 3
        --
        -- Within each 15-task block, IDs are generated with a deterministic
        -- pseudo-random permutation:
        --   perm = ((7*j + 3) mod 15) + 1, with j = 0..14
        --
        -- This gives a non-trivial insertion order while keeping the final
        -- expected list fully deterministic.
        --
        -- Final expected ordered list after all 60 inserts:
        --   priority 0 block -> IDs from range 1..15 in pseudo-random FIFO order
        --   priority 1 block -> IDs from range 16..30 in pseudo-random FIFO order
        --   priority 2 block -> IDs from range 31..45 in pseudo-random FIFO order
        --   priority 3 block -> IDs from range 46..60 in pseudo-random FIFO order
        --------------------------------------------------

        for i in 1 to 60 loop
            j_int    := (i - 1) mod 15;
            perm_int := ((7 * j_int + 3) mod 15) + 1;

            if i <= 15 then
                -- First block inserted: priority 2, IDs 31..45
                prio_int    := 2;
                task_id_int := 30 + perm_int;
            elsif i <= 30 then
                -- Second block inserted: priority 0, IDs 1..15
                prio_int    := 0;
                task_id_int := perm_int;
            elsif i <= 45 then
                -- Third block inserted: priority 1, IDs 16..30
                prio_int    := 1;
                task_id_int := 15 + perm_int;
            else
                -- Fourth block inserted: priority 3, IDs 46..60
                prio_int    := 3;
                task_id_int := 45 + perm_int;
            end if;

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
                std_logic_vector(to_unsigned(task_id_int, 6)),
                std_logic_vector(to_unsigned(prio_int, 2)),
                i
            );
        end loop;

        -- Final expected ordered list after STEP 1:
        -- priority 0: [4,11,3,10,2,9,1,8,15,7,14,6,13,5,12]
        -- priority 1: [19,26,18,25,17,24,16,23,30,22,29,21,28,20,27]
        -- priority 2: [34,41,33,40,32,39,31,38,45,37,44,36,43,35,42]
        -- priority 3: [49,56,48,55,47,54,46,53,60,52,59,51,58,50,57]
        check_ram_count(RAM, 60, "STEP 1 final count after near-full build");
        check_ram_value(RAM, 1,  encode_task(4, 0),  "STEP 1 RAM(1)");
        check_ram_value(RAM, 15, encode_task(12, 0), "STEP 1 RAM(15)");
        check_ram_value(RAM, 16, encode_task(19, 1), "STEP 1 RAM(16)");
        check_ram_value(RAM, 30, encode_task(27, 1), "STEP 1 RAM(30)");
        check_ram_value(RAM, 31, encode_task(34, 2), "STEP 1 RAM(31)");
        check_ram_value(RAM, 45, encode_task(42, 2), "STEP 1 RAM(45)");
        check_ram_value(RAM, 46, encode_task(49, 3), "STEP 1 RAM(46)");
        check_ram_value(RAM, 60, encode_task(57, 3), "STEP 1 RAM(60)");

        report "STEP 1 OK: built a 60-task near-full list with pseudo-random IDs and insertion order 2 -> 0 -> 1 -> 3.";


        --------------------------------------------------
        -- STEP 2: POP five tasks from the near-full list
        --
        -- Expected popped IDs:
        --   4, 11, 3, 10, 2
        --
        -- These are the first five elements of the priority-0 block created
        -- by STEP 1. This stresses repeated POP and long left-shift behavior.
        --------------------------------------------------

        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 59, "000100");
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 58, "001011");
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 57, "000011");
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 56, "001010");
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "01", "000000", "00", 55, "000010");

        -- Remaining ordered list now begins with:
        -- priority 0: [9,1,8,15,7,14,6,13,5,12]
        check_ram_count(RAM, 55, "STEP 2 count after five pops from near-full list");
        check_ram_value(RAM, 1,  encode_task(9, 0),   "STEP 2 RAM(1)");
        check_ram_value(RAM, 10, encode_task(12, 0),  "STEP 2 RAM(10)");
        check_ram_value(RAM, 11, encode_task(19, 1),  "STEP 2 RAM(11)");
        check_ram_value(RAM, 25, encode_task(27, 1),  "STEP 2 RAM(25)");
        check_ram_value(RAM, 26, encode_task(34, 2),  "STEP 2 RAM(26)");
        check_ram_value(RAM, 40, encode_task(42, 2),  "STEP 2 RAM(40)");
        check_ram_value(RAM, 41, encode_task(49, 3),  "STEP 2 RAM(41)");
        check_ram_value(RAM, 55, encode_task(57, 3),  "STEP 2 RAM(55)");

        report "STEP 2 OK: repeated pop and long-list shifting verified.";


        --------------------------------------------------
        -- STEP 3: Reach the full capacity of 63 tasks
        --
        -- After STEP 2 the list contains 55 tasks.
        -- We now insert 8 more tasks to reach exactly 63 valid tasks.
        --
        -- Reused IDs from the popped head:
        --   4, 11, 3, 10, 2
        -- New high IDs not used before:
        --   61, 62, 63
        --
        -- Insert priorities are chosen to stress insertion into different
        -- existing priority blocks.
        --------------------------------------------------

        -- Insert into priority-0 block
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "111101", "00", 56); -- 61 / prio 0
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "000100", "00", 57); -- 4  / prio 0

        -- Insert into priority-1 block
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "001011", "01", 58); -- 11 / prio 1
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "000011", "01", 59); -- 3  / prio 1

        -- Insert into priority-2 block
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "111110", "10", 60); -- 62 / prio 2
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "001010", "10", 61); -- 10 / prio 2

        -- Insert into priority-3 block
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "111111", "11", 62); -- 63 / prio 3
        run_operation(tb_clk, tb_start, tb_op, tb_i_task_id, tb_task_priority, tb_done, RAM(0), tb_o_task_id, "10", "000010", "11", 63); -- 2  / prio 3

        -- Final expected structure at full capacity (63 tasks):
        -- priority 0: [9,1,8,15,7,14,6,13,5,12,61,4]
        -- priority 1: [19,26,18,25,17,24,16,23,30,22,29,21,28,20,27,11,3]
        -- priority 2: [34,41,33,40,32,39,31,38,45,37,44,36,43,35,42,62,10]
        -- priority 3: [49,56,48,55,47,54,46,53,60,52,59,51,58,50,57,63,2]
        check_ram_count(RAM, 63, "STEP 3 count after reaching full capacity");
        check_ram_value(RAM, 1,  encode_task(9, 0),   "STEP 3 RAM(1)");
        check_ram_value(RAM, 10, encode_task(12, 0),  "STEP 3 RAM(10)");
        check_ram_value(RAM, 11, encode_task(61, 0),  "STEP 3 RAM(11)");
        check_ram_value(RAM, 12, encode_task(4, 0),   "STEP 3 RAM(12)");
        check_ram_value(RAM, 13, encode_task(19, 1),  "STEP 3 RAM(13)");
        check_ram_value(RAM, 29, encode_task(3, 1),   "STEP 3 RAM(29)");
        check_ram_value(RAM, 30, encode_task(34, 2),  "STEP 3 RAM(30)");
        check_ram_value(RAM, 46, encode_task(10, 2),  "STEP 3 RAM(46)");
        check_ram_value(RAM, 47, encode_task(49, 3),  "STEP 3 RAM(47)");
        check_ram_value(RAM, 62, encode_task(63, 3),  "STEP 3 RAM(62)");
        check_ram_value(RAM, 63, encode_task(2, 3),   "STEP 3 RAM(63)");

        report "STEP 3 OK: reached full capacity (63 tasks) and verified boundary positions.";


        --------------------------------------------------
        -- STEP 4: AGE the full-capacity list once
        --
        -- This stresses one long AGE pass over the maximum valid list size.
        -- Count must remain 63.
        -- Priorities must update as:
        --   0 -> 1
        --   1 -> 2
        --   2 -> 3
        --   3 -> 3
        -- Order must remain unchanged.
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
            "00",
            "000000",
            "00",
            63
        );

        check_ram_count(RAM, 63, "STEP 4 count after long age at full capacity");
        check_ram_value(RAM, 1,  encode_task(9, 1),   "STEP 4 RAM(1)");
        check_ram_value(RAM, 10, encode_task(12, 1),  "STEP 4 RAM(10)");
        check_ram_value(RAM, 11, encode_task(61, 1),  "STEP 4 RAM(11)");
        check_ram_value(RAM, 12, encode_task(4, 1),   "STEP 4 RAM(12)");
        check_ram_value(RAM, 13, encode_task(19, 2),  "STEP 4 RAM(13)");
        check_ram_value(RAM, 29, encode_task(3, 2),   "STEP 4 RAM(29)");
        check_ram_value(RAM, 30, encode_task(34, 3),  "STEP 4 RAM(30)");
        check_ram_value(RAM, 46, encode_task(10, 3),  "STEP 4 RAM(46)");
        check_ram_value(RAM, 47, encode_task(49, 3),  "STEP 4 RAM(47)");
        check_ram_value(RAM, 62, encode_task(63, 3),  "STEP 4 RAM(62)");
        check_ram_value(RAM, 63, encode_task(2, 3),   "STEP 4 RAM(63)");

        report "STEP 4 OK: long AGE pass at full capacity verified.";


        --------------------------------------------------
        -- final result
        --------------------------------------------------

        report "=========================================";
        assert false
            report "Simulation Ended! TESTBENCH 9 PASSED (near-full stress test)"
            severity failure;
    end process;

end architecture;