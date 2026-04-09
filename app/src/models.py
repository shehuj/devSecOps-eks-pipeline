from dataclasses import dataclass
from typing import List


@dataclass
class Product:
    id: int
    name: str
    price: float
    stock: int


PRODUCTS: List[Product] = [
    Product(id=1, name="Widget A", price=9.99, stock=100),
    Product(id=2, name="Gadget B", price=24.99, stock=50),
    Product(id=3, name="Doohickey C", price=4.99, stock=200),
]

CART: List[dict] = []
