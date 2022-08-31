require "test_helper"

class ProfessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get professions_new_url
    assert_response :success
  end

  test "should get create" do
    get professions_create_url
    assert_response :success
  end

  test "should get edit" do
    get professions_edit_url
    assert_response :success
  end

  test "should get update" do
    get professions_update_url
    assert_response :success
  end

  test "should get index" do
    get professions_index_url
    assert_response :success
  end

  test "should get show" do
    get professions_show_url
    assert_response :success
  end

  test "should get destroy" do
    get professions_destroy_url
    assert_response :success
  end
end
