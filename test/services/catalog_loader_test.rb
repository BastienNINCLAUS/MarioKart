require "test_helper"
require "tmpdir"

class CatalogLoaderTest < ActiveSupport::TestCase
  YAML_FIL_ROUGE = <<~YAML
    kind: fil_rouge
    items:
      - key: a
        name: A
        description: Faire A.
        points: 3
        visibility: secret_duo
  YAML

  def with_catalog_dir(files)
    Dir.mktmpdir do |dir|
      files.each { |name, content| File.write(File.join(dir, name), content) }
      yield dir
    end
  end

  test "le catalogue du dépôt se charge entièrement" do
    items = load_catalog

    assert_equal %w[complication fil_rouge secret_task special_action], items.map(&:kind).uniq.sort
    assert_equal items.size, CatalogItem.count
  end

  test "le chargement est idempotent" do
    load_catalog

    assert_no_difference "CatalogItem.count" do
      load_catalog
    end
  end

  test "un élément modifié dans le YAML est mis à jour sans doublon" do
    with_catalog_dir("a.yml" => YAML_FIL_ROUGE) { |dir| CatalogLoader.call(dir) }
    updated = YAML_FIL_ROUGE.sub("points: 3", "points: 4")

    with_catalog_dir("a.yml" => updated) do |dir|
      assert_no_difference "CatalogItem.count" do
        CatalogLoader.call(dir)
      end
    end
    assert_equal 4, CatalogItem.find_by!(key: "a").points
  end

  test "une clé en double entre fichiers est refusée sans rien charger" do
    files = { "a.yml" => YAML_FIL_ROUGE, "b.yml" => YAML_FIL_ROUGE }

    with_catalog_dir(files) do |dir|
      error = assert_raises(CatalogLoader::Error) { CatalogLoader.call(dir) }
      assert_match(/en double.*a/, error.message)
    end
    assert_equal 0, CatalogItem.count
  end

  test "un élément invalide lève une erreur explicite et annule tout le chargement" do
    invalid = YAML_FIL_ROUGE.sub("secret_duo", "public").sub("key: a", "key: b")

    with_catalog_dir("a.yml" => YAML_FIL_ROUGE, "b.yml" => invalid) do |dir|
      error = assert_raises(CatalogLoader::Error) { CatalogLoader.call(dir) }
      assert_match(/\Ab :/, error.message)
    end
    assert_equal 0, CatalogItem.count
  end

  test "un fichier mal formé est refusé" do
    with_catalog_dir("a.yml" => "- juste une liste\n") do |dir|
      assert_raises(CatalogLoader::Error) { CatalogLoader.call(dir) }
    end
  end

  test "un type inconnu dans un fichier est refusé" do
    with_catalog_dir("a.yml" => YAML_FIL_ROUGE.sub("fil_rouge", "inconnu")) do |dir|
      assert_raises(CatalogLoader::Error) { CatalogLoader.call(dir) }
    end
  end
end
