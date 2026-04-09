def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "healthy"


def test_get_products(client):
    response = client.get("/products")
    assert response.status_code == 200
    products = response.get_json()
    assert len(products) > 0
    assert "name" in products[0]
    assert "price" in products[0]


def test_get_product(client):
    response = client.get("/products/1")
    assert response.status_code == 200
    data = response.get_json()
    assert data["id"] == 1


def test_get_product_not_found(client):
    response = client.get("/products/9999")
    assert response.status_code == 404


def test_get_cart_empty(client):
    response = client.get("/cart")
    assert response.status_code == 200


def test_add_to_cart(client):
    response = client.post("/cart", json={"product_id": 1, "quantity": 2})
    assert response.status_code == 201
    assert response.get_json()["message"] == "Added to cart"


def test_add_to_cart_no_product_id(client):
    response = client.post("/cart", json={})
    assert response.status_code == 400


def test_add_to_cart_product_not_found(client):
    response = client.post("/cart", json={"product_id": 9999})
    assert response.status_code == 404
