from flask import Blueprint, jsonify, request
from .models import PRODUCTS, CART

main = Blueprint("main", __name__)


@main.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


@main.route("/products")
def get_products():
    return jsonify([
        {"id": p.id, "name": p.name, "price": p.price, "stock": p.stock}
        for p in PRODUCTS
    ])


@main.route("/products/<int:product_id>")
def get_product(product_id):
    product = next((p for p in PRODUCTS if p.id == product_id), None)
    if not product:
        return jsonify({"error": "Product not found"}), 404
    return jsonify({"id": product.id, "name": product.name, "price": product.price, "stock": product.stock})


@main.route("/cart", methods=["GET"])
def get_cart():
    return jsonify(CART)


@main.route("/cart", methods=["POST"])
def add_to_cart():
    data = request.get_json(silent=True)
    if not data or "product_id" not in data:
        return jsonify({"error": "product_id required"}), 400

    product_id = data["product_id"]
    quantity = int(data.get("quantity", 1))

    product = next((p for p in PRODUCTS if p.id == product_id), None)
    if not product:
        return jsonify({"error": "Product not found"}), 404

    CART.append({
        "product_id": product_id,
        "name": product.name,
        "quantity": quantity,
        "price": product.price,
    })
    return jsonify({"message": "Added to cart"}), 201
