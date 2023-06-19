require "test_helper"

class MedicalServicesControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get medical_services_new_url
    assert_response :success
  end

  test "should get create" do
    get medical_services_create_url
    assert_response :success
  end

  test "should get edit" do
    get medical_services_edit_url
    assert_response :success
  end

  test "should get update" do
    get medical_services_update_url
    assert_response :success
  end

  test "should get index" do
    get medical_services_index_url
    assert_response :success
  end

  test "should get destroy" do
    get medical_services_destroy_url
    assert_response :success
  end
end
