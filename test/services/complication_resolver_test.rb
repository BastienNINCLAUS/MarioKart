require "test_helper"

# Rules Collections/complications.md : effet de chaque complication sur les points de position.
class ComplicationResolverTest < ActiveSupport::TestCase
  BASE = { 1 => 8, 2 => 6, 3 => 4, 4 => 2 }.freeze
  # duo 10 premier, 20 deuxième, 30 troisième, 40 quatrième
  POSITIONS = { 10 => 1, 20 => 2, 30 => 3, 40 => 4 }.freeze

  def resolve(key, targets: [], positions: POSITIONS, base: BASE)
    ComplicationResolver.call(key: key, positions: positions, targets: targets, base_points: base)
  end

  test "toutes les complications du catalogue sont gérées" do
    load_catalog

    assert_equal CatalogItem.complication.pluck(:key).sort, ComplicationResolver::KEYS.sort
  end

  test "les clés automatiques et manuelles correspondent au calcul déclaré dans le catalogue" do
    load_catalog

    CatalogItem.complication.each do |item|
      list = item.params["calculation"] == "auto" ? ComplicationResolver::AUTO_KEYS : ComplicationResolver::MANUAL_KEYS
      assert_includes list, item.key
    end
  end

  test "une complication inconnue est refusée" do
    assert_raises(ArgumentError) { resolve("inconnue") }
  end

  test "les amoureux : plus d'une place d'écart, aucun des deux ne gagne de points" do
    assert_equal({ 10 => 0, 20 => 6, 30 => 0, 40 => 2 }, resolve("les_amoureux", targets: [ 10, 30 ]))
  end

  test "les amoureux : une place d'écart ou moins, les points sont conservés" do
    assert_equal BASE.values, resolve("les_amoureux", targets: [ 10, 20 ]).values
    assert_equal BASE.values, resolve("les_amoureux", targets: [ 40, 30 ]).values
  end

  test "les rivaux : le duo tiré qui finit devant gagne en plus les points de l'autre" do
    assert_equal({ 10 => 8, 20 => 6 + 2, 30 => 4, 40 => 2 }, resolve("les_rivaux", targets: [ 40, 20 ]))
    assert_equal({ 10 => 8 + 4, 20 => 6, 30 => 4, 40 => 2 }, resolve("les_rivaux", targets: [ 30, 10 ]))
  end

  test "dernier couronné : le dernier gagne le double" do
    assert_equal({ 10 => 8, 20 => 6, 30 => 4, 40 => 4 }, resolve("dernier_couronne"))
  end

  test "podium inversé : le dernier reçoit les points du premier" do
    assert_equal({ 10 => 2, 20 => 4, 30 => 6, 40 => 8 }, resolve("podium_inverse"))
  end

  test "podium inversé avec un nombre impair de duos garde le duo du milieu" do
    assert_equal({ 10 => 2, 20 => 4, 30 => 6 }, resolve("podium_inverse", positions: { 10 => 1, 20 => 2, 30 => 3 }, base: { 1 => 6, 2 => 4, 3 => 2 }))
  end

  test "les complications manuelles ne changent pas les points automatiques" do
    assert_equal BASE.values, resolve("pas_d_objets_offensifs").values
    assert_equal BASE.values, resolve("objet_unique").values
  end

  test "les points sont rendus pour chaque duo, quelle que soit la complication" do
    ComplicationResolver::KEYS.each do |key|
      assert_equal POSITIONS.keys.sort, resolve(key, targets: [ 10, 30 ]).keys.sort, key
    end
  end
end
