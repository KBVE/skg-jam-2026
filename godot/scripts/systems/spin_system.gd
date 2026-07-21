## Rotates the "Mesh" child of every entity that has a C_Spin component.
class_name SpinSystem
extends System


func query() -> QueryBuilder:
	return q.with_all([C_Spin])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for entity in entities:
		var spin := entity.get_component(C_Spin) as C_Spin
		var mesh := entity.get_node_or_null("Mesh") as MeshInstance3D
		if spin and mesh:
			mesh.rotate_y(spin.speed * delta)
			mesh.rotate_x(spin.speed * 0.6 * delta)
