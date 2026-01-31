class Ingredient {
  final String id;
  final String name;
  final String icon; // Emoji or Asset Path
  final String doshaImpact; // Vata, Pitta, or Kapha

  Ingredient({required this.id, required this.name, required this.icon, required this.doshaImpact});
}

final List<Ingredient> pantryItems = [
  Ingredient(id: "1", name: "Tomato", icon: "🍅", doshaImpact: "Pitta Aggravating"),
  Ingredient(id: "2", name: "Ginger", icon: "🫚", doshaImpact: "Vata Balancing"),
  Ingredient(id: "3", name: "Ghee", icon: "🧈", doshaImpact: "Tridoshic"),
  Ingredient(id: "4", name: "Potato", icon: "🥔", doshaImpact: "Vata Aggravating"),
  Ingredient(id: "5", name: "Spinach", icon: "🥬", doshaImpact: "Pitta Balancing"),
  Ingredient(id: "6", name: "Rice", icon: "🍚", doshaImpact: "Tridoshic"),
];