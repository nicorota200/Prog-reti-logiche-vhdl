# Testbench

Eseguire `python tests/run.py` dalla radice del repository, con GHDL e Python 3 disponibili nel terminale. Lo script usa una directory temporanea e riconosce il messaggio finale di successo nelle asserzioni dei testbench originali. GHDL accetta la variabile condivisa usata da `tb_utils_pkg.vhd` per numerare le operazioni con l'opzione `-frelaxed-rules`.

## Copertura

Il [testbench di riferimento](tb_reference.vhd) esegue una sequenza di inserimenti, estrazioni, aging e svuotamento. La tabella dei nove test aggiuntivi è nella sezione 3.2 della [relazione](../docs/relazione.pdf).

## Reset e inizializzazione
- [x] Reset iniziale con verifica che la lista venga portata a vuota (`RAM(0)=0`)
- [x] Verifica della fase di init post-reset con `DONE` non basso prima del completamento
- [x] Reset seguito immediatamente da operazioni (senza attendere)
- [x] Reset multipli consecutivi
- [x] Reset a metà operazione

## OP = 11 (clear)
- [x] Clear su lista vuota
- [x] Clear su lista piena
- [x] Clear seguito immediatamente da insert
- [x] Clear non tocca altri bit oltre a RAM(0)
    - non essenziale per la specifica, rilevante per verificare l'efficienza dell'implementazione

## OP = 10 (insert)
- [x] Insert su lista vuota
- [x] Insert con priorità 0 in testa
- [x] Insert con priorità 3 in coda
- [x] Insert con priorità intermedia / FIFO a parità
- [x] Insert con molti elementi
- [x] Insert con priorità uguale all'ultimo elemento
- [x] Insert con priorità uguale al primo elemento

## OP = 01 (pop)
- [x] Pop su lista vuota
- [x] Verifica che `o_task_id = 0` nel caso di lista vuota
- [x] Verifica di `o_task_id` al `DONE=1` nel caso già testato di pop su vuoto
- [x] Pop su lista con un solo elemento
- [x] Pop su lista con N elementi
- [x] Verifica di `o_task_id` al `DONE=1` su lista non vuota

## OP = 00 (age)
- [x] Age su lista vuota
- [x] Age con tutti i task già a priorità 3
- [x] Age con task misti
- [x] Age ripetuto fino a saturazione completa
- [x] Verifica che l'ordinamento non cambi dopo age

## Sequenze combinate
- [x] Più operazioni consecutive senza reset intermedio (caso base su lista vuota)
- [x] Insert × N → Pop × N
- [x] Insert → Age → Insert
- [x] Insert → Age ripetuto → Pop
- [x] Clear → Insert → Pop
- [x] Pop da lista 1 elemento → Pop su lista vuota 
- [x] FIFO a parità con insert multipli e pop ripetuti 

## Protocollo START/DONE
- [x] Operazioni consecutive senza reset intermedio (caso base)
- [x] Handshake base `START↑ ... DONE↑ ... START↓ ... DONE↓`
- [x] START che rimane alto mentre DONE è alto
- [x] Verifica esplicita che una nuova operazione parta solo dopo nuova discesa e risalita di START 

## Stress vicino alla capacità massima

### Capacità / boundary conditions
- [x] Insert ripetuti fino a portare la lista vicino a 63 elementi
- [x] Verifica corretta di `RAM(0)` vicino al massimo
- [x] Verifica delle ultime posizioni valide (`RAM(62)`, `RAM(63)`)
- [x] Verifica assenza di errori off-by-one sull’ultimo elemento valido

### Stress su OP = 10 (insert)
- [x] Verifica che insert continui a funzionare correttamente su lista molto lunga
- [x] Verifica che l’ordinamento resti corretto anche con molte scansioni interne
- [x] Verifica che la FIFO a parità continui a valere anche su liste grandi
- [x] Verifica che gli indirizzi usati durante la ricerca/inserimento restino corretti vicino al limite

### Stress su OP = 01 (pop)
- [x] Pop ripetuti da lista quasi piena
- [x] Verifica di `o_task_id` durante pop su lista lunga
- [x] Verifica dello shifting corretto dopo pop quando la lista è molto lunga
- [x] Verifica che il conteggio venga decrementato correttamente anche vicino al massimo

### Riutilizzo delle posizioni liberate
- [x] Dopo alcuni `pop`, nuovi `insert` riusano correttamente le posizioni disponibili
- [x] Verifica che il contenuto valido venga ricostruito correttamente senza corruzione della lista

### Robustezza della sequenza lunga
- [x] Verifica che una lunga sequenza di operazioni consecutive completi sempre correttamente
- [x] Verifica implicita di assenza di blocchi / percorsi FSM incoerenti in casi lunghi
- [x] Verifica che il protocollo `START/DONE` continui a funzionare correttamente anche su operazioni con latenza maggiore
