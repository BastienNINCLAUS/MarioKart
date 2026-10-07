require "test_helper"

# rules.md §10 : catalogue de départ (fil rouge, complications, tâches secrètes, actions spéciales).
class CatalogItemTest < ActiveSupport::TestCase
  def build_item(**overrides)
    CatalogItem.new({ kind: "fil_rouge", key: "test_item", name: "Test", description: "Faire un test.",
                      points: 3, visibility: "secret_duo" }.merge(overrides))
  end

  test "un élément valide est accepté pour chaque type" do
    assert build_item.valid?
    assert build_item(kind: "secret_task").valid?
    assert build_item(kind: "special_action", visibility: "secret_until_done").valid?
    assert build_item(kind: "complication", visibility: "public", points: 0,
                      params: { "type" => "global", "calculation" => "auto" }).valid?
  end

  test "nom, description et clé sont obligatoires" do
    assert_not build_item(name: "").valid?
    assert_not build_item(description: "").valid?
    assert_not build_item(key: "").valid?
  end

  test "la clé est unique et sans espace ni majuscule" do
    build_item.save!

    assert_not build_item.valid?
    assert_not build_item(key: "Clé invalide").valid?
  end

  test "les points sont un entier positif ou nul" do
    assert build_item(points: 0).valid?
    assert_not build_item(points: -1).valid?
    assert_not build_item(points: 1.5).valid?
    assert_not build_item(points: nil).valid?
  end

  test "un type inconnu est refusé" do
    assert_not build_item(kind: "inconnu").valid?
  end

  test "la visibilité doit correspondre au type" do
    assert_not build_item(kind: "fil_rouge", visibility: "public").valid?
    assert_not build_item(kind: "special_action", visibility: "secret_duo").valid?
    assert_not build_item(kind: "complication", visibility: "secret_duo",
                          params: { "type" => "global", "calculation" => "auto" }).valid?
  end

  test "une complication exige un type et un calcul reconnus" do
    base = { kind: "complication", visibility: "secret", points: 0 }

    assert_not build_item(**base, params: {}).valid?
    assert_not build_item(**base, params: { "type" => "global" }).valid?
    assert_not build_item(**base, params: { "type" => "inconnu", "calculation" => "auto" }).valid?
    assert_not build_item(**base, params: { "type" => "global", "calculation" => "inconnu" }).valid?
  end

  test "une complication ciblée exige un nombre de duos ciblés" do
    base = { kind: "complication", visibility: "public", points: 0 }
    targeted = { "type" => "targeted", "calculation" => "auto" }

    assert_not build_item(**base, params: targeted).valid?
    assert_not build_item(**base, params: targeted.merge("targets" => 0)).valid?
    assert build_item(**base, params: targeted.merge("targets" => 2)).valid?
  end
end
