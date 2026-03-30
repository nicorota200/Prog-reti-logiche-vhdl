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

architecture Behavioral of project_reti_logiche is

    type state_t is (
        RESET_MEM,
        IDLE,
        GET_TASK_REQ,
        DECODE_OP,
        DECREMENT_PR,
        DECREMENT_PR_REQ,
        DECREMENT_PR_WRITE,
        REMOVE_FIRST,
        REMOVE_FIRST_WRITE,
        INSERT_TASK,
        CLEAR_RAM,
        WAIT_START_LOW
    );    

    signal state_reg, state_next : state_t;
    signal n_reg: unsigned(7 downto 0);
    signal n_task_id: std_logic_vector(5 downto 0);
    signal n_task_priority: std_logic_vector(1 downto 0);
    signal n_op: std_logic_vector(1 downto 0);
    signal idx_reg: unsigned(7 downto 0);


    begin

        -- Gestione reset asincrono

        process(i_clk, i_rst)
        begin
            if(i_rst = '1') then
                state_reg <= RESET_MEM;
                n_reg <= (others => '0');
                n_task_id <= (others => '0');
                n_task_priority <= (others => '0');
                n_op <= (others => '0');
                idx_reg <= (others => '0')
                
            elsif rising_edge(i_clk) then
                state_reg <= state_next;

                if state_reg=DECODE_OP then
                    n_reg <= unsigned(i_mem_data);

                elsif state_reg=IDLE and i_start='1' then
                    n_op <= i_op;
                    idx_reg <= (others => '0');

                elsif state_reg=DECREMENT_PR and idx_reg<n_reg then
                    idx_reg <= idx_reg + 1;
                end if;
            end if;
        end process;

        -- Gestione transizioni di stato
        
        process(all)
        begin

            --DEFAULT

            o_done <= '0';
            o_task_id <= (others => '0');

            o_mem_en <= '0';
            o_mem_we <= '0';
            o_mem_data <= (others => '0');
            o_mem_addr <= (others => '0');
            

            state_next <= state_reg;

            --FSM

            case(state_reg) is
                when RESET_MEM =>
                    o_done <= '1';
                    o_mem_we <= '1';
                    o_mem_en <= '1';
                    o_mem_addr <= (others => '0');
                    o_mem_data <= (others => '0');
                    state_next <= WAIT_START_LOW;
                
                when IDLE =>
                    if(i_start = '1') then
                        state_next <= GET_TASK_REQ;
                    else
                        state_next <= IDLE;
                    end if;

                when GET_TASK_REQ =>
                    o_mem_en <= '1';
                    o_mem_addr <= (others => '0');
                    state_next <= DECODE_OP;
                    
                when DECODE_OP =>
                    if(n_op = "00") then
                        state_next <= DECREMENT_PR;

                    elsif(n_op = "01") then
                        state_next <= REMOVE_FIRST;

                    elsif(n_op = "10") then
                        state_next <= INSERT_TASK;

                    elsif(n_op = "11") then
                        state_next <= RESET_MEM;

                    end if;


                --DECREMENT_PR
                    
                when DECREMENT_PR =>
                    if(n_reg = 0 or idx_reg>=n_reg) then
                        o_done <= '1';  --Fattibile in uno stato solo uguale per tutti
                        state_next <= WAIT_START_LOW;
                    else
                        state_next <= DECREMENT_PR_REQ;
                    end if;

                when DECREMENT_PR_REQ =>
                    o_mem_en <= '1';
                    o_mem_addr <= std_logic_vector(resize(idx_reg, 16));
                    state_next <= DECREMENT_PR_WRITE;

                when DECREMENT_PR_WRITE =>
                    o_mem_en <= '1';
                    o_mem_we <= '1';
                    if i_mem_data(1 downto 0) /= "11" then
                        o_mem_data <= i_mem_data(7 downto 2) & std_logic_vector(unsigned(i_mem_data(1 downto 0)) + 1);
                    else
                        o_mem_data <= i_mem_data(7 downto 2) & "11";
                    end if;
                    o_mem_addr <= std_logic_vector(resize(idx_reg, 16));
                    state_next <= DECREMENT_PR;

                
                --REMOVE_FIRST

                when REMOVE_FIRST =>
                    if(n_reg = 0 or idx_reg>=n_reg) then
                        o_done <= '1';  --Fattibile in uno stato solo uguale per tutti
                        o_task_id <= (others => '0');
                        state_next <= WAIT_START_LOW;
                    else
                        o_mem_en <= '1';
                        o_mem_addr <= "0000000000000001";
                        state_next <= REMOVE_FIRST_WRITE;

                when REMOVE_FIRST_WRITE =>
                    o_mem_en <= '1';
                    o_task_id <= i_mem_data(7 downto 2);
                    if(n_reg == 1) then
                        state_next <= RESET_MEM;
                    else
                        o_mem_we <= '1';
                        o_mem_data <= i_mem_data;
                        o_mem_addr <= std_logic_vector(resize(idx_reg, 16));
                        state_next <= REMOVE_FIRST;
                    end if;
                    

                when WAIT_START_LOW =>
                    o_done <= '1';
                    if i_start = '0' then
                        state_next <= IDLE;
                    end if;
                        
                    
                    

                    
                        

    

                    
            



            
            
        






end architecture Behavioral;