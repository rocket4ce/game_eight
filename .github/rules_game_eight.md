Baraja y Cartas
Cantidad de Cartas en Total
Se utilizan 2 barajas inglesas:
Baraja roja: 52 cartas.
Baraja azul: 52 cartas.
Total: 104 cartas.

Reparto de Cartas por Jugador
Cada jugador recibe 8 cartas al azar del mazo.
Ejemplos:
2 jugadores → 16 cartas repartidas, quedan 88 en el mazo.
3 jugadores → 24 cartas repartidas, quedan 80 en el mazo.

Inicio de la Partida
Cada jugador lanza un dado de 6 caras una sola vez.
El jugador con el número mayor inicia la partida (primer turno).
El resto de turnos avanzan según la posición o el orden definido.
Si todos obtienen el mismo número en el dado, se repite hasta que haya un ganador.
Turnos y Jugadas
En su turno, cada jugador puede:
Jugar cartas (descargar trios o escaleras en la mesa, o añadir cartas a combinaciones ya existentes).
Robar una carta del mazo.

Si la carta robada sirve para jugar, el jugador puede decidir usarla o pasar.
Si no sirve (o no desea usarla), el turno finaliza forzosamente.

Estado del Jugador (player_on / player_off)
Al inicio, todos están en estado player_off.
Cuando un jugador logra jugar (descargar) cartas por primera vez, su estado pasa a player_on y se mantiene así.
Solo los jugadores con estado player_on pueden poner cartas en la mesa.
Ejemplo de Mano, Mesa y Decks en ASCII
A continuación, se muestra un ejemplo de cómo podrían verse las cartas del jugador y la mesa:
hand_cards = [
  %Card{ position: 0,  card: 'Ace',    type: :spades,   deck: :blue},
  %Card{ position: 1,  card: '10',     type: :hearts,   deck: :red},
  %Card{ position: 2,  card: '4',      type: :clubs,    deck: :blue},
  %Card{ position: 3,  card: 'Queen',  type: :diamonds, deck: :red},
  %Card{ position: 4,  card: '7',      type: :spades,   deck: :blue},
  %Card{ position: 5,  card: 'King',   type: :spades,   deck: :blue}
]

--------------- mano del jugador -------------------   -------------------- decks ---------------------------
.----.  .----.  .----.  .----.  .----.  .----.                           .----.  todas las otras cartas
| A♠ |  |10♥ |  | 4♣ |  | Q♦ |  | 7♠ |  | K♠ |                           |    |  para robar
|  A |  | 10 |  |  4 |  |  Q |  |  7 |  |  K |                           |    |
'----'  '----'  '----'  '----'  '----'  '----'                           '----'
----------------------------------------------------   ------------------------------------------------------

table = %{
  table: %{
    trio: [
      %Card{ position: 0, card: 'King', type: :spades,   deck: :red},
      %Card{ position: 1, card: 'King', type: :hearts,   deck: :blue},
      %Card{ position: 2, card: 'King', type: :diamonds, deck: :blue}
    ]
  }
}
-------------------- mesa ---------------------------
.----.  .----.  .----.
| K♠ |  | K♥ |  | K♦ |
|  K |  |  K |  |  K |
'----'  '----'  '----'
----------------------------------------------------
En este ejemplo, la mesa tiene un "trio" de Reyes. El jugador, por su parte, tiene 6 cartas en mano.
Ahora, si el jugador tiene un King adicional (por ejemplo, K♥) y quiere añadirlo a ese trio, podría hacerlo en su turno (si su estado es player_on).
Tras jugar esa carta, la mano y la mesa quedarían así:
hand_cards = [
  %Card{ position: 0, card: 'Ace',   type: :spades,   deck: :blue},
  %Card{ position: 1, card: '10',    type: :hearts,   deck: :red},
  %Card{ position: 2, card: '4',     type: :clubs,    deck: :blue},
  %Card{ position: 3, card: 'Queen', type: :diamonds, deck: :red},
  %Card{ position: 4, card: '7',     type: :spades,   deck: :blue}
]

--------------- mano del jugador -------------------  -------------------- decks ---------------------------
.----.  .----.  .----.  .----.  .----.                           .----.  todas las otras cartas
| A♠ |  |10♥ |  | 4♣ |  | Q♦ |  | 7♠ |                           |    |  para robar
|  A |  | 10 |  |  4 |  |  Q |  |  7 |                           |    |
'----'  '----'  '----'  '----'  '----'                           '----'
----------------------------------------------------   ------------------------------------------------------

table = %{
  table: %{
    trio_0: [
      %Card{ position: 0, card: 'King', type: :spades,   deck: :red},
      %Card{ position: 1, card: 'King', type: :hearts,   deck: :blue},
      %Card{ position: 2, card: 'King', type: :diamonds, deck: :blue},
      %Card{ position: 3, card: 'King', type: :spades,   deck: :blue}
    ]
  }
}

-------------------- mesa ---------------------------
.----.  .----.  .----.  .----.
| K♠ |  | K♥ |  | K♦ |  | K♠ |
|  K |  |  K |  |  K |  |  K |
'----'  '----'  '----'  '----'
----------------------------------------------------
El jugador retiró el "King" de su mano y lo agregó al trio de la mesa. Si no tiene más cartas que jugar o ya usó todos sus movimientos, puede pasar y ceder el turno al siguiente jugador.
Ejemplo de Mano, Mesa y Decks en ASCII con Escalera
hand_cards = [
  %Card{ position: 0,  card: 'Ace',    type: :hearts,   deck: :blue},
  %Card{ position: 1,  card: '2',      type: :hearts,   deck: :blue},
  %Card{ position: 2,  card: '3',      type: :hearts,   deck: :blue},
  %Card{ position: 3,  card: '4',      type: :hearts,   deck: :blue},
  %Card{ position: 4,  card: '7',      type: :spades,   deck: :blue},
  %Card{ position: 5,  card: 'King',   type: :spades,   deck: :blue}
]

--------------- mano del jugador -------------------   -------------------- decks ---------------------------
.----.  .----.  .----.  .----.  .----.  .----.                           .----.  todas las otras cartas
| A♥ |  | 2♥ |  | 3♥ |  | 4♥ |  | 7♠ |  | K♠ |                           |    |  para robar
|  A |  |  2 |  |  3 |  |  4 |  |  7 |  |  K |                           |    |
'----'  '----'  '----'  '----'  '----'  '----'                           '----'
----------------------------------------------------   ------------------------------------------------------

table = %{
  table: %{
    trio: [
      %Card{ position: 0, card: 'King', type: :spades,   deck: :red},
      %Card{ position: 1, card: 'King', type: :hearts,   deck: :blue},
      %Card{ position: 2, card: 'King', type: :diamonds, deck: :blue}
    ]
  }
}
-------------------- mesa ---------------------------
.----.  .----.  .----.
| K♠ |  | K♥ |  | K♦ |
|  K |  |  K |  |  K |
'----'  '----'  '----'
----------------------------------------------------
En este ejemplo, el jugador tiene una escalera de corazones (A♥, 2♥, 3♥) y puede jugarla en su turno.
Tras jugar la escalera, la mano y la mesa quedarían así:
hand_cards = [
  %Card{ position: 0, card: '7',     type: :spades,   deck: :blue},
  %Card{ position: 1, card: 'King',  type: :spades,   deck: :blue}
]

--------------- mano del jugador -------------------  -------------------- decks ---------------------------
.----.  .----.
| 7♠ |  | K♠ |                                                 .----.  todas las otras cartas
|  7 |  |  K |                                                 |    |  para robar
'----'  '----'                                                 '----'
----------------------------------------------------   ------------------------------------------------------

table = %{
  table: %{
    trio_0: [
      %Card{ position: 0, card: 'King', type: :spades,   deck: :red},
      %Card{ position: 1, card: 'King', type: :hearts,   deck: :blue},
      %Card{ position: 2, card: 'King', type: :diamonds, deck: :blue}
    ],
    escalera_0: [
      %Card{ position: 0, card: 'Ace',   type: :hearts,   deck: :blue},
      %Card{ position: 1, card: '2',     type: :hearts,   deck: :blue},
      %Card{ position: 2, card: '3',     type: :hearts,   deck: :blue},
    ]
  }
}

-------------------- mesa ---------------------------
.----.  .----.  .----.  .----.
| A♥ |  | 2♥ |  | 3♥ |  | 4♥ |
|  A |  |  2 |  |  3 |  |  4 |
'----'  '----'  '----'  '----'
----------------------------------------------------
El jugador retiró las cartas de su mano y las agregó como una escalera en la mesa.
Ejemplo de Jugada Compleja con Movimientos en Mesa
hand_cards = [
  %Card{ position: 0,  card: 'King',   type: :diamonds, deck: :blue},
  %Card{ position: 1,  card: '4',      type: :clubs,    deck: :blue},
  %Card{ position: 2,  card: '4',      type: :hearts,   deck: :blue},
  %Card{ position: 3,  card: '5',      type: :clubs,    deck: :blue},
  %Card{ position: 4,  card: '5',      type: :hearts,   deck: :blue}
]

--------------- mano del jugador -------------------   -------------------- decks ---------------------------
.----.  .----.  .----.  .----.  .----.                           .----.  todas las otras cartas
| K♦ |  | 4♣ |  | 4♥ |  | 5♣ |  | 5♥ |                           |    |  para robar
|  K |  |  4 |  |  4 |  |  5 |  |  5 |                           |    |
'----'  '----'  '----'  '----'  '----'                           '----'
----------------------------------------------------   ------------------------------------------------------

table = %{
  table: %{
    escalera_0: [
      %Card{ position: 0, card: 'Ace',   type: :diamonds, deck: :blue},
      %Card{ position: 1, card: '2',     type: :diamonds, deck: :blue},
      %Card{ position: 2, card: '3',     type: :diamonds, deck: :blue},
      %Card{ position: 3, card: '4',     type: :diamonds, deck: :blue},
      %Card{ position: 4, card: '5',     type: :diamonds, deck: :blue}
    ]
  }
}
-------------------- mesa ---------------------------
.----.  .----.  .----.  .----.  .----.
| A♦ |  | 2♦ |  | 3♦ |  | 4♦ |  | 5♦ |
|  A |  |  2 |  |  3 |  |  4 |  |  5 |
'----'  '----'  '----'  '----'  '----'
----------------------------------------------------
En este ejemplo, el jugador tiene varias cartas que puede usar para movimientos complejos en la mesa.
Tras jugar las cartas y realizar movimientos en la mesa, la mano y la mesa quedarían así:
hand_cards = [
  %Card{ position: 0, card: 'King',   type: :diamonds, deck: :blue}
]

--------------- mano del jugador -------------------  -------------------- decks ---------------------------
.----.
| K♦ |                                                           .----.  todas las otras cartas
|  K |                                                           |    |  para robar
'----'                                                           '----'
----------------------------------------------------   ------------------------------------------------------

table = %{
  table: %{
    escalera_0: [
      %Card{ position: 0, card: 'Ace',   type: :diamonds, deck: :blue},
      %Card{ position: 1, card: '2',     type: :diamonds, deck: :blue},
      %Card{ position: 2, card: '3',     type: :diamonds, deck: :blue},
      %Card{ position: 3, card: '4',     type: :diamonds, deck: :blue}
    ],
    trio_0: [
      %Card{ position: 0, card: '5',     type: :diamonds, deck: :blue},
      %Card{ position: 1, card: '5',     type: :clubs,    deck: :blue},
      %Card{ position: 2, card: '5',     type: :hearts,   deck: :blue}
    ],
    trio_1: [
      %Card{ position: 0, card: '4',     type: :diamonds, deck: :blue},
      %Card{ position: 1, card: '4',     type: :clubs,    deck: :blue},
      %Card{ position: 2, card: '4',     type: :hearts,   deck: :blue}
    ]
  }
}

-------------------- mesa ---------------------------
.----.  .----.  .----.  .----.
| A♦ |  | 2♦ |  | 3♦ |  | 4♦ |
|  A |  |  2 |  |  3 |  |  4 |
'----'  '----'  '----'  '----'
.----.  .----.  .----.
| 5♦ |  | 5♣ |  | 5♥ |
|  5 |  |  5 |  |  5 |
'----'  '----'  '----'
.----.  .----.  .----.
| 4♦ |  | 4♣ |  | 4♥ |
|  4 |  |  4 |  |  4 |
'----'  '----'  '----'
----------------------------------------------------
El jugador retiró las cartas de su mano y las agregó como combinaciones en la mesa, realizando movimientos complejos.
Jugadas en Mesa

Un jugador con estado player_on dispone de 5 movimientos en su turno.
Cada "movimiento" puede ser:
Descargar un trio (3 cartas del mismo valor pero palos diferentes).
Descargar una escalera (3 o más cartas consecutivas del mismo palo).
Agregar cartas a combinaciones ya existentes.
Mover cartas dentro de la mesa (si la variante lo permite).