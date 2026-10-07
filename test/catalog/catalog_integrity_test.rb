require "test_helper"

# Garde-fou : le catalogue YAML doit rester cohérent avec "Rules Collections" et jouable de 4 à 9 joueurs.
class CatalogIntegrityTest < ActiveSupport::TestCase
  COLLECTIONS_DIR = Rails.root.join("Rules Collections")
  MARKDOWN_BY_KIND = {
    "fil_rouge" => "taches-fil-rouge.md",
    "complication" => "complications.md",
    "secret_task" => "taches-secretes-individuelles.md",
    "special_action" => "actions-speciales.md"
  }.freeze
  VISIBILITY_LABELS = { "Publique" => "public", "Secrète" => "secret" }.freeze
  CALCULATION_LABELS = { "Auto" => "auto", "Manuel" => "manual" }.freeze
  TYPE_LABELS = { "Ciblée" => "targeted", "Globale" => "global", "Contrainte jeu vidéo" => "constraint" }.freeze
  MAX_DUOS = Game::MAX_PLAYERS / 2

  setup { load_catalog }

  def markdown_rows(kind)
    lines = File.readlines(COLLECTIONS_DIR.join(MARKDOWN_BY_KIND.fetch(kind)), chomp: true, encoding: "UTF-8")
    table = lines.select { |line| line.start_with?("|") }.map { |line| line.split("|")[1..].map(&:strip) }
    headers = table.first
    table.drop(2).map { |cells| headers.zip(cells).to_h }
  end

  test "chaque type du catalogue a un fichier YAML et un fichier Rules Collections" do
    assert_equal CatalogItem.kinds.keys.sort, MARKDOWN_BY_KIND.keys.sort
    yaml_kinds = Dir[Rails.root.join("db/catalog/*.yml")].map { |file| YAML.safe_load_file(file)["kind"] }

    assert_equal CatalogItem.kinds.keys.sort, yaml_kinds.sort
    MARKDOWN_BY_KIND.each_value { |file| assert COLLECTIONS_DIR.join(file).exist?, "#{file} est introuvable" }
  end

  test "chaque type contient assez d'éléments distincts pour 9 joueurs (4 duos)" do
    CatalogItem.kinds.each_key do |kind|
      count = CatalogItem.where(kind: kind).count
      assert_operator count, :>=, MAX_DUOS, "#{kind} : #{count} élément(s), #{MAX_DUOS} requis pour tirer sans doublon"
    end
  end

  test "les noms de chaque type sont identiques à ceux de Rules Collections" do
    MARKDOWN_BY_KIND.each_key do |kind|
      expected = markdown_rows(kind).map { |row| row.fetch("Nom") }

      assert_equal expected.sort, CatalogItem.where(kind: kind).pluck(:name).sort, "#{kind} : noms différents"
    end
  end

  test "les points de chaque élément sont identiques à ceux de Rules Collections" do
    (MARKDOWN_BY_KIND.keys - [ "complication" ]).each do |kind|
      markdown_rows(kind).each do |row|
        points = row["Points"] || row["Points par course"]

        assert_equal points.to_i, CatalogItem.find_by!(kind: kind, name: row["Nom"]).points, "#{row['Nom']} : points différents"
      end
    end
  end

  test "type, calcul et visibilité des complications sont identiques à Rules Collections" do
    markdown_rows("complication").each do |row|
      item = CatalogItem.find_by!(kind: "complication", name: row["Nom"])
      type_label = row["Type"][/\A[^(]+/].strip

      assert_equal TYPE_LABELS.fetch(type_label), item.params["type"], "#{row['Nom']} : type"
      assert_equal CALCULATION_LABELS.fetch(row["Calcul"]), item.params["calculation"], "#{row['Nom']} : calcul"
      assert_equal VISIBILITY_LABELS.fetch(row["Visibilité"]), item.visibility, "#{row['Nom']} : visibilité"
      expected_targets = row["Type"][/\((\d+) duos\)/, 1].to_i
      assert_equal expected_targets, item.params["targets"].to_i, "#{row['Nom']} : duos ciblés"
    end
  end

  test "les complications ciblées ne visent pas plus de duos qu'une partie à 4 joueurs n'en a" do
    CatalogItem.complication.each do |item|
      assert_operator item.params["targets"].to_i, :<=, Game::MIN_PLAYERS / 2, item.name if item.params["type"] == "targeted"
    end
  end
end
