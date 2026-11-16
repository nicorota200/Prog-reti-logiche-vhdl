# Prova finale di Reti Logiche

**Nicola Rota e Ives Mathis Tagako**

Politecnico di Milano, A.A. 2025/2026 · 30 e lode

Abbiamo progettato in VHDL un modulo che gestisce **fino a 63 task** in una RAM sincrona esterna. La coda è ordinata dalla priorità più alta (0) alla più bassa (3). A parità di priorità, l'inserimento preserva l'ordine di arrivo.

[Sorgente VHDL finale](src/project_reti_logiche.vhd) · [Relazione di progetto](docs/relazione.pdf) · [Specifica ufficiale](docs/specifica.pdf)

## Architettura

La RAM memorizza il numero di task all'indirizzo 0 e i task negli indirizzi successivi. Ogni task occupa un byte, con **6 bit per l'ID** e **2 bit per la priorità**.

Il modulo `project_reti_logiche` usa una **macchina a stati finiti con 18 stati** per sequenziare gli accessi alla RAM. Un processo sequenziale aggiorna lo stato e i registri, mentre un processo combinatorio determina le transizioni e i comandi verso la memoria. Durante l'inserimento, un registro temporaneo conserva il task spostato fino alla scrittura successiva.

| `OP` | Operazione | Comportamento |
| --- | --- | --- |
| `00` | Aging | Incrementa il valore numerico delle priorità fino a 3, senza riordinare la coda. |
| `01` | Estrazione | Rimuove il primo task e restituisce il suo ID. A coda vuota restituisce 0. |
| `10` | Inserimento | Colloca il nuovo task dopo tutti quelli con la stessa priorità. |
| `11` | Svuotamento | Azzera il contatore della coda in RAM. |

Nel protocollo **`START/DONE`**, la logica esterna avvia una richiesta alzando `START` mentre `DONE` è basso. Il modulo alza `DONE` a operazione conclusa e aspetta che `START` torni basso prima di accettare un'altra richiesta. Dopo il reset asincrono, mantiene `DONE` alto fino all'azzeramento del contatore in RAM.

## Simulazione

Abbiamo verificato le quattro operazioni, il reset durante l'esecuzione, il protocollo `START/DONE` e il comportamento a piena capacità. La suite comprende il testbench di riferimento e nove test aggiuntivi. [Copertura dei test](tests/README.md)

Per eseguire la suite dalla radice del repository servono GHDL e Python 3.

```sh
python tests/run.py
```

## Sintesi

Abbiamo sintetizzato il modulo con Vivado 2016.1 per il dispositivo `xc7k70tfbg676-1`, con un periodo di clock di **20 ns**. Il progetto occupa **162 LUT e 45 registri**. Il report di timing riporta un margine minimo di setup (**WNS**) di **+16,549 ns**.

[Vincolo di clock](vivado/clock.xdc) · [Report di utilizzo](vivado/reports/utilization.txt) · [Report di timing](vivado/reports/timing.rpx)
