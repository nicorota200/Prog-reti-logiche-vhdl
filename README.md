# Prova finale di Reti Logiche

**Politecnico di Milano · A.A. 2025/2026 · Valutazione 30 e lode**

Abbiamo progettato in VHDL un modulo hardware che gestisce una coda di task ordinata per priorità in una RAM sincrona esterna. Il modulo `project_reti_logiche` è controllato da una macchina a 18 stati e usa il protocollo `START/DONE`.

**Autori:** Nicola Rota e Ives Mathis Tagako.

## Materiali

- [Sorgente VHDL finale](src/project_reti_logiche.vhd), identico al file di consegna `10906471_10986748.vhd`
- [Relazione di progetto](docs/relazione.pdf) con schema funzionale, diagramma della FSM, sintesi e simulazioni
- [Specifica ufficiale](docs/specifica.pdf), revisione del 24 febbraio 2026
- [Testbench e copertura dei test](tests/README.md)

## Funzionamento

La RAM conserva il numero di task all'indirizzo 0 e fino a 63 task agli indirizzi da 1 a `N`. Ogni task occupa un byte con 6 bit per l'ID e 2 per la priorità. La priorità 0 è la più alta.

| `OP` | Operazione | Comportamento |
| --- | --- | --- |
| `00` | Aging | Incrementa il valore numerico delle priorità fino a 3, preservando l'ordine dei task. |
| `01` | Estrazione | Rimuove il primo task e ne restituisce l'ID. Se la coda è vuota restituisce 0. |
| `10` | Inserimento | Inserisce il nuovo task dopo quelli di pari priorità. |
| `11` | Svuotamento | Scrive zero nel contatore in RAM, rendendo vuota la coda. |

Il reset è asincrono e mantiene `DONE` alto durante l'inizializzazione della RAM. Per avviare un'operazione, la logica esterna alza `START` quando `DONE` è basso, lo mantiene alto fino al completamento e poi lo riabbassa.

## Simulazione con GHDL

Con GHDL e Python 3 disponibili nel terminale, eseguire dalla radice del repository:

```sh
python tests/run.py
```

Il comando esegue il testbench di riferimento e i nove testbench aggiuntivi. La suite verifica le quattro operazioni, il reset durante l'esecuzione, il protocollo `START/DONE` e il comportamento fino a 63 task.

## Sintesi con Vivado

Il top level di sintesi è `project_reti_logiche`. Per la configurazione descritta nella relazione, usare il dispositivo `xc7k70tfbg676-1`, il [sorgente VHDL](src/project_reti_logiche.vhd) e il [vincolo di clock a 20 ns](vivado/clock.xdc). I testbench forniscono il modello della RAM esterna per la simulazione.

La relazione riporta per Vivado 2016.1 un utilizzo di **162 LUT** e **45 registri**, con un **WNS di +16,549 ns** rispetto al periodo di 20 ns. I risultati sono documentati nella sezione 3.1 della relazione e nei report originali di [utilizzo delle risorse](vivado/reports/utilization.txt) e [timing](vivado/reports/timing.rpx) di Vivado.
