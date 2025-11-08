import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Constantes
const String apiToken = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzUxMiIsImtpZCI6IjI4YTMxOGY3LTAwMDAtYTFlYi03ZmExLTJjNzQzM2M2Y2NhNSJ9.eyJpc3MiOiJzdXBlcmNlbGwiLCJhdWQiOiJzdXBlcmNlbGw6Z2FtZWFwaSIsImp0aSI6ImI0MDcyNjE2LTJhNzMtNDkzYy1iOTUyLWRjZTRjYTA2MmJiMiIsImlhdCI6MTc2MjYwNzYwNSwic3ViIjoiZGV2ZWxvcGVyL2I4NmMwYTVmLTY5MTUtM2IxMi0wODQ3LWEwMzU5ZTNlMWRjNyIsInNjb3BlcyI6WyJyb3lhbGUiXSwibGltaXRzIjpbeyJ0aWVyIjoiZGV2ZWxvcGVyL3NpbHZlciIsInR5cGUiOiJ0aHJvdHRsaW5nIn0seyJjaWRycyI6WyIxNzAuMjM5LjIyNy43MCJdLCJ0eXBlIjoiY2xpZW50In1dfQ.OLm1ua8uaJaLO7DMBTmXH7JsuMp2oNc5nQv6QVENnhisbUsoouA2yzln6T0xj7RdW42lqLWQ-ndtD0p6wNdbMQ";

void main() {
  runApp(const MyApp());
}

// --- Modelos de Dados ---

class CardModel {
  final String name;
  final int level;
  final String iconUrl;
  final double elixirCost;
  final String id;

  CardModel.fromJson(Map<String, dynamic> json)
      : name = (json['name'] as String? ?? 'Desconhecida'),
        level = (json['level'] as int? ?? 0),
        elixirCost = (json['elixir'] as int? ?? 0).toDouble(), // CORRIGIDO
        iconUrl = (json['iconUrls'] as Map<String, dynamic>?)?['medium'] as String? ?? 'url_padrao', // Adicionando segurança extra aqui
        id = (json['id'] as int? ?? 0).toString(); // Adicionando segurança extra aqui
        
  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CardModel && runtimeType == other.runtimeType && id == other.id;
}

class PlayerInfo {
  final String name;
  final List<CardModel> ownedCards;

  PlayerInfo({required this.name, required this.ownedCards});
}

class DeckValidationResult {
  final String rule;
  final bool passed;
  final String message;

  DeckValidationResult({required this.rule, required this.passed, required this.message});
}

// Widget principal
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deck Maker CR',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF673AB7),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// Página inicial
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  bool _isPlayerLoaded = false; // Controla qual tela exibir
  PlayerInfo? _playerInfo;
  List<CardModel> _currentDeck = [];

  // Mapeamento Detalhado de Papéis (Chave: Nome da Carta, Valor: Lista de Papéis)
  final Map<String, List<String>> _cardRoles = {
    // Condições de Vitória
    "Royal Giant": ["CV", "TANK", "ANTI_AIR"], "Wall Breakers": ["CV", "SUPPORT_CYCLE"],
    "Goblin Barrel": ["CV", "SUPPORT_SWARM", "BAIT"], "X-Bow": ["CV", "BUILDING", "SIEGE"],
    "Giant": ["CV", "TANK"], "Royal Hogs": ["CV", "SUPPORT_SWARM", "SPLIT_ATTACK"],
    "Graveyard": ["CV", "SUPPORT_SWARM"], "Lava Hound": ["CV", "TANK", "ANTI_AIR", "AIRFECTA"],
    "Golem": ["CV", "TANK", "BEATDOWN"], "Ram Rider": ["CV", "BRIDGE_SPAM", "CV"],
    "Skeleton Barrel": ["CV", "SUPPORT_SWARM", "BAIT"], "Miner": ["CV", "MINI_TANK", "SUPPORT_CYCLE"],
    "Mortar": ["CV", "BUILDING", "SIEGE"], "Elixir Golem": ["CV", "TANK", "BEATDOWN"],
    "Battle Ram": ["CV", "BRIDGE_SPAM", "CV"], "Balloon": ["CV", "AIRFECTA"],
    "Three Musketeers": ["CV", "SPLIT_ATTACK", "FIREBALL_BAIT", "CV"],

    // Feitiços Leves (SPELL_LIGHT)
    "The Log": ["SPELL_LIGHT"], "Zap": ["SPELL_LIGHT", "RESET"],
    "Snowball": ["SPELL_LIGHT"], "Arrows": ["SPELL_LIGHT", "ANTI_AIR"],
    "Giant Snowball": ["SPELL_LIGHT"], "Barbarian Barrel": ["SPELL_LIGHT", "MINI_TANK"],

    // Feitiços Pesados (SPELL_HEAVY)
    "Rocket": ["SPELL_HEAVY"], "Lightning": ["SPELL_HEAVY", "RESET"],
    "Fireball": ["SPELL_HEAVY"], "Poison": ["SPELL_HEAVY"], "Earthquake": ["SPELL_HEAVY"],

    // Mini Tanques / Tropas Pesadas / Anti-Tank
    "Knight": ["MINI_TANK", "SUPPORT_CYCLE"], "Valkyrie": ["MINI_TANK", "SUPPORT_SPLASH"],
    "Mega Knight": ["MINI_TANK", "COUNTER_PUNCH"], "P.E.K.K.A": ["ANTI_TANK"],

    // Cartas de Defesa Aérea (ANTI_AIR)
    "Musketeer": ["ANTI_AIR"], "Electro Wizard": ["ANTI_AIR", "RESET"],
    "Dart Goblin": ["ANTI_AIR", "BAIT"], "Hunter": ["ANTI_AIR", "ANTI_TANK"],
    "Minions": ["ANTI_AIR", "SUPPORT_SWARM"], "Baby Dragon": ["ANTI_AIR", "SUPPORT_SPLASH"],
    "Inferno Dragon": ["ANTI_AIR", "ANTI_TANK"], "Archers": ["ANTI_AIR", "SUPPORT_CYCLE"],
    "Witch": ["ANTI_AIR", "SUPPORT_SWARM"], "Wizard": ["ANTI_AIR", "SUPPORT_SPLASH"],
    
    // Construções
    "Tesla": ["BUILDING", "ANTI_AIR"], "Inferno Tower": ["BUILDING", "ANTI_TANK"],
    "Tombstone": ["BUILDING", "DISTRACTION"], "Bomb Tower": ["BUILDING", "SUPPORT_SPLASH"],
    
    // Distrações / Enxame
    "Barbarians": ["SUPPORT_SWARM", "ANTI_TANK"], "Goblins": ["SUPPORT_SWARM", "DISTRACTION"],
    "Skeleton Army": ["SUPPORT_SWARM", "DISTRACTION"], "Ice Golem": ["MINI_TANK", "SUPPORT_CYCLE", "DISTRACTION"],
  };


  // --- Lógica de Busca de Jogador ---

  Future<void> buscarPlayer(String playerTag) async {
    final tag = playerTag.trim();
    if (tag.isEmpty) return;

    setState(() {
      _loading = true;
      _playerInfo = null;
      _isPlayerLoaded = false;
      _currentDeck = [];
    });

    final url = Uri.parse("https://api.clashroyale.com/v1/players/%23$tag");
    
    const maxRetries = 3;
    int retryCount = 0;
    http.Response? response;

    while (retryCount < maxRetries) {
      try {
        response = await http.get(
          url,
          headers: {"Authorization": "Bearer $apiToken"},
        );

        if (response.statusCode == 200) {
          break;
        } else if (response.statusCode == 429) {
          await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
          retryCount++;
          continue;
        } else {
          break;
        }
      } catch (e) {
        response = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro de conexão: $e")),
        );
        break;
      }
    }

    if (response != null && response.statusCode == 200) {
      try {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final cardsData = List<Map<String, dynamic>>.from(data["cards"]);
        final cards = cardsData.map((json) => CardModel.fromJson(json)).toList();

        final filteredCards = cards.where((c) => _cardRoles.containsKey(c.name)).toList();
        
        setState(() {
          _playerInfo = PlayerInfo(name: data["name"] as String, ownedCards: filteredCards);
          _isPlayerLoaded = true; // MUITO IMPORTANTE: Alterna para a tela de construção
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao processar dados: $e")),
        );
      }
    } else {
      String errorMessage = "Erro desconhecido.";
      if (response != null) {
         try {
           final errorData = json.decode(response.body);
           errorMessage = "Erro ${response.statusCode}: ${errorData['reason'] ?? errorData['message'] ?? 'Falha na busca'}";
         } catch(_) {
           errorMessage = "Erro ${response.statusCode}: ${response.body}";
         }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _loading = false);
  }

  // --- Lógica de Manipulação do Deck ---

  void toggleCardInDeck(CardModel card) {
    setState(() {
      if (_currentDeck.contains(card)) {
        _currentDeck.remove(card);
      } else {
        if (_currentDeck.length < 8) {
          _currentDeck.add(card);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("O Deck já tem 8 cartas!")),
          );
        }
      }
    });
  }
  
  // --- Lógica de Validação e Fluxo Guiado ---
  
  // Retorna o papel principal que o usuário deve selecionar em seguida
  Map<String, List<String>> _getRequiredRolesForNextStep() {
    final counts = _countRolesInDeck(_currentDeck);

    if (_currentDeck.length < 8) {
      if (counts["CV"]! < 1) {
        return {"**1. Condição de Vitória** (Recomendado: 1-2 CVs)": ["CV"]};
      }
      if (counts["SPELL_LIGHT"]! < 1) {
        return {"**2. Feitiço Leve** (Obrigatório: Pelo menos 1)": ["SPELL_LIGHT"]};
      }
      if (counts["SPELL_HEAVY"]! < 1) {
        // Se já tiver uma CV e um Spell Light, sugere o pesado, que é comum
        return {"**3. Feitiço Pesado** (Opcional)": ["SPELL_HEAVY"]};
      }
      
      // Slots restantes: Sugere papéis para equilibrar a defesa e o ataque
      return {"**4. Complete o Deck** (Faltam ${8 - _currentDeck.length} cartas)": 
        ["ANTI_AIR", "MINI_TANK", "ANTI_TANK", "DISTRACTION", "BUILDING", "SUPPORT_SPLASH", "SUPPORT_SWARM"]
      };
    }
    
    // Deck Completo
    return {"Deck Completo!": []};
  }

  Map<String, int> _countRolesInDeck(List<CardModel> deck) {
    final counts = {
      "CV": 0, "SPELL_LIGHT": 0, "SPELL_HEAVY": 0, "ANTI_AIR": 0,
      "MINI_TANK": 0, "ANTI_TANK": 0, "DISTRACTION": 0, "BUILDING": 0,
    };
    
    for (var card in deck) {
      final roles = _cardRoles[card.name] ?? [];
      for (var role in roles) {
        if (counts.containsKey(role)) {
          counts[role] = counts[role]! + 1;
        }
      }
    }
    
    return counts;
  }
  
  List<DeckValidationResult> _validateDeck(List<CardModel> deck) {
    final counts = _countRolesInDeck(deck);
    final spellCount = counts["SPELL_LIGHT"]! + counts["SPELL_HEAVY"]!;
    
    final totalElixir = deck.fold(0.0, (sum, card) => sum + card.elixirCost);
    final avgElixir = deck.length > 0 ? totalElixir / deck.length : 0.0;

    final results = <DeckValidationResult>[];
    
    results.add(DeckValidationResult(
      rule: "Tamanho do Deck",
      passed: deck.length == 8,
      message: "Exatamente 8 cartas. Atual: ${deck.length}",
    ));

    results.add(DeckValidationResult(
      rule: "Condição de Vitória (CV)",
      passed: counts["CV"]! >= 1 && counts["CV"]! <= 2,
      message: "Ideal 1-2 CVs. Encontrado: ${counts["CV"]}",
    ));
    
    results.add(DeckValidationResult(
      rule: "Feitiços Totais",
      passed: spellCount >= 1 && spellCount <= 3,
      message: "Ideal 1-3 Feitiços. Encontrado: $spellCount",
    ));

    results.add(DeckValidationResult(
      rule: "Feitiço Leve (Obrigatório)",
      passed: counts["SPELL_LIGHT"]! >= 1,
      message: "Pelo menos 1 Feitiço Leve. Encontrado: ${counts["SPELL_LIGHT"]}",
    ));

    results.add(DeckValidationResult(
      rule: "Defesa Anti-Aérea",
      passed: counts["ANTI_AIR"]! >= 2,
      message: "Pelo menos 2 Cartas Anti-Aéreas. Encontrado: ${counts["ANTI_AIR"]}",
    ));
    
    results.add(DeckValidationResult(
      rule: "Custo Médio de Elixir",
      passed: avgElixir >= 2.6 && avgElixir <= 4.5,
      message: "Média: ${avgElixir.toStringAsFixed(2)} (Ideal 2.6 - 4.5)",
    ));

    return results;
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPlayerLoaded ? "Construção de Deck Guiada" : "Deck Maker CR"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isPlayerLoaded) 
              _SearchScreen(
                controller: _controller,
                loading: _loading,
                buscarPlayer: buscarPlayer,
              )
            else if (_playerInfo != null)
              _GuidedDeckBuilder(
                playerInfo: _playerInfo!,
                currentDeck: _currentDeck,
                toggleCardInDeck: toggleCardInDeck,
                validateDeck: _validateDeck,
                cardRoles: _cardRoles,
                getRequiredRolesForNextStep: _getRequiredRolesForNextStep,
              )
            else 
              const Center(child: Text("Ocorreu um erro ao carregar os dados.")),
          ],
        ),
      ),
    );
  }
}

// --- Widgets de Componentes ---

// Tela Inicial de Busca
class _SearchScreen extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final Function(String) buscarPlayer;

  const _SearchScreen({
    required this.controller,
    required this.loading,
    required this.buscarPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            "Bem-vindo ao Deck Maker CR!",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        _TagInputField(
          controller: controller,
          onSubmitted: buscarPlayer,
          isLoading: loading,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
          ),
          onPressed: loading ? null : () => buscarPlayer(controller.text.trim()),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Buscar Jogador"),
        ),
      ],
    );
  }
}

// Widget para campo de entrada da tag
class _TagInputField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;
  final bool isLoading;

  const _TagInputField({
    required this.controller,
    required this.onSubmitted,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: !isLoading,
      decoration: InputDecoration(
        labelText: "Digite sua tag (sem #)",
        hintText: "Exemplo: 8PY8RYPJ",
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        prefixIcon: const Icon(Icons.person),
      ),
      onSubmitted: onSubmitted,
    );
  }
}

// Seção principal de construção do deck guiada
class _GuidedDeckBuilder extends StatelessWidget {
  final PlayerInfo playerInfo;
  final List<CardModel> currentDeck;
  final Function(CardModel) toggleCardInDeck;
  final List<DeckValidationResult> Function(List<CardModel>) validateDeck;
  final Map<String, List<String>> cardRoles;
  final Map<String, List<String>> Function() getRequiredRolesForNextStep;

  const _GuidedDeckBuilder({
    required this.playerInfo,
    required this.currentDeck,
    required this.toggleCardInDeck,
    required this.validateDeck,
    required this.cardRoles,
    required this.getRequiredRolesForNextStep,
  });

  @override
  Widget build(BuildContext context) {
    final requiredStep = getRequiredRolesForNextStep();
    final stepTitle = requiredStep.keys.first;
    final requiredRoles = requiredStep.values.first;

    // 1. Filtra as cartas disponíveis pelo papel requerido
    final availableCards = playerInfo.ownedCards.where((card) {
      if (currentDeck.contains(card)) return false; 
      
      // Se o passo não tem roles específicos (Deck Completo), para a listagem
      if (requiredRoles.isEmpty) return false;

      // Se estamos no passo de preenchimento (final), mostra todas as restantes
      if (stepTitle.contains("Complete o Deck")) return true;
      
      // Se estamos em um passo essencial (CV, Spell Light/Heavy)
      final cardRolesList = cardRoles[card.name] ?? [];
      return requiredRoles.any((requiredRole) => cardRolesList.contains(requiredRole));
    }).toList();
    
    // Na fase de preenchimento, ordena por custo de elixir para melhor visualização
    if (stepTitle.contains("Complete o Deck")) {
       availableCards.sort((a, b) => a.elixirCost.compareTo(b.elixirCost));
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Exibição do Deck Atual (Fica no topo)
        _CurrentDeckDisplay(currentDeck: currentDeck, toggleCardInDeck: toggleCardInDeck),
        const SizedBox(height: 20),

        // Painel de Validação (Aparece assim que o deck começa a ser montado)
        if (currentDeck.length > 0)
          _DeckValidationPanel(validationResults: validateDeck(currentDeck)),
        const SizedBox(height: 20),
        
        // Guia de Seleção
        Card(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: currentDeck.length < 8 ? Colors.amber : Colors.green,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              stepTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: currentDeck.length < 8 ? Colors.amberAccent : Colors.greenAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        if (availableCards.isNotEmpty && currentDeck.length < 8)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cartas Disponíveis para o Passo Atual:",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              // Lista de Cartas Filtradas para o Passo
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: availableCards.map((card) => _CardTile(
                  card: card,
                  isSelected: currentDeck.contains(card),
                  onTap: () => toggleCardInDeck(card),
                  showRole: true,
                  cardRoles: cardRoles,
                )).toList(),
              ),
            ],
          )
        else if (currentDeck.length == 8)
          const Center(
            child: Text(
              "Seu deck está completo! Verifique o painel de validação para otimizar.",
              style: TextStyle(fontSize: 16, color: Colors.greenAccent),
              textAlign: TextAlign.center,
            ),
          )
        else
          const Center(
            child: Text(
              "Você não possui cartas disponíveis para este papel no momento ou o deck está completo.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

// Painel de regras de validação do deck
class _DeckValidationPanel extends StatelessWidget {
  final List<DeckValidationResult> validationResults;

  const _DeckValidationPanel({required this.validationResults});

  @override
  Widget build(BuildContext context) {
    // Se o deck não tiver 8 cartas, exibe apenas o custo médio de elixir e as regras básicas
    if (validationResults.isEmpty || validationResults.first.rule != "Tamanho do Deck") {
      return const SizedBox.shrink();
    }
    
    final elixirRule = validationResults.last;
    final otherRules = validationResults.where((r) => r.rule != "Tamanho do Deck" && r.rule != "Custo Médio de Elixir").toList();


    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Validação do Deck (Regras Essenciais)",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            // Exibe as regras de papel
            ...otherRules.map((result) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(
                      result.passed ? Icons.check_circle : Icons.error,
                      color: result.passed ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${result.rule}: ${result.message}",
                        style: TextStyle(
                          color: result.passed ? Colors.green[200] : Colors.red[300],
                          fontWeight: result.passed ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(height: 16),
            // Exibe a regra do custo de elixir separadamente
            Row(
              children: [
                Icon(
                  elixirRule.passed ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                  color: elixirRule.passed ? Colors.blue : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${elixirRule.rule}: ${elixirRule.message}",
                    style: TextStyle(
                      color: elixirRule.passed ? Colors.blue[300] : Colors.orange[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Exibe as 8 cartas atualmente no deck
class _CurrentDeckDisplay extends StatelessWidget {
  final List<CardModel> currentDeck;
  final Function(CardModel) toggleCardInDeck;

  const _CurrentDeckDisplay({required this.currentDeck, required this.toggleCardInDeck});

  double getAvgElixir() {
    if (currentDeck.isEmpty) return 0.0;
    final total = currentDeck.fold(0.0, (sum, card) => sum + card.elixirCost);
    return total / currentDeck.length;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Deck Atual (${currentDeck.length}/8)",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                "Custo Médio de Elixir: ${getAvgElixir().toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.yellowAccent),
              ),
              const Divider(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  ...currentDeck.map((card) => _CardTile(
                    card: card,
                    isSelected: true,
                    onTap: () => toggleCardInDeck(card),
                    isDeckSlot: true,
                  )),
                  // Slots vazios
                  ...List.generate(8 - currentDeck.length, (index) => const _EmptyCardSlot()),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Slot de carta vazia
class _EmptyCardSlot extends StatelessWidget {
  const _EmptyCardSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey, width: 2, style: BorderStyle.solid),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_box, color: Colors.grey),
            SizedBox(height: 4),
            Text("Vazio", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}


// Widget para exibir uma carta
class _CardTile extends StatelessWidget {
  final CardModel card;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDeckSlot;
  final bool showRole;
  final Map<String, List<String>>? cardRoles;

  const _CardTile({
    required this.card,
    required this.isSelected,
    required this.onTap,
    this.isDeckSlot = false,
    this.showRole = false,
    this.cardRoles,
  });

  String _getRoleDisplayName(String role) {
    switch (role) {
      case "CV": return "Condição de Vitória";
      case "SPELL_LIGHT": return "Feitiço Leve";
      case "SPELL_HEAVY": return "Feitiço Pesado";
      case "ANTI_AIR": return "Anti-Aéreo";
      case "MINI_TANK": return "Mini Tanque";
      case "ANTI_TANK": return "Anti-Tanque";
      case "DISTRACTION": return "Distração";
      case "BUILDING": return "Construção";
      case "SUPPORT_SPLASH": return "Suporte Splash";
      case "SUPPORT_SWARM": return "Enxame";
      case "SUPPORT_CYCLE": return "Ciclo";
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayRole = (cardRoles != null && cardRoles!.containsKey(card.name)) 
        ? _getRoleDisplayName(cardRoles![card.name]!.first) 
        : "";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        height: 130,
        decoration: BoxDecoration(
          color: isDeckSlot 
              ? Colors.black54 
              : isSelected 
                  ? Colors.green.withOpacity(0.3) 
                  : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.greenAccent : Colors.blueGrey, 
            width: isSelected ? 3 : 1
          ),
        ),
        child: Column(
          children: [
            // Custo de Elixir (Overlay)
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: const EdgeInsets.only(top: 4, left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple[800],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.yellow, width: 1),
                ),
                child: Text(
                  card.elixirCost.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            
            // Imagem da Carta
            Image.network(
              card.iconUrl,
              width: 60,
              height: 60,
              errorBuilder: (context, error, stackTrace) => 
                const Icon(Icons.cancel, size: 60, color: Colors.red),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  width: 60,
                  height: 60,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                );
              },
            ),
            
            // Nome e Papel
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Column(
                children: [
                  Text(
                    card.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                  if (showRole && displayRole.isNotEmpty)
                    Tooltip(
                      message: "Papéis: ${cardRoles![card.name]?.map(_getRoleDisplayName).join(', ')}",
                      child: Text(
                        displayRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: Colors.blueGrey[300], fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Text(
                      "Lv. ${card.level}",
                      style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}