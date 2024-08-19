datatype Tree =
  | Leaf
  | Node(value: int, left: Tree, right: Tree)

function Depth(t: Tree): nat
{
  match t
    case Leaf => 0
    case Node(_, l, r) => 1 + if Depth(l) > Depth(r) then Depth(l) else Depth(r)
}

method Main()
{
  var leaf: Tree := Leaf;
  var node1: Tree := Node(3, Leaf, Leaf);
  var node2: Tree := Node(5, node1, Leaf);
  var root: Tree := Node(10, node1, node2);

	print root, "\n";
	print node1.value, "\n";
	print node2.value, "\n";
	print root.value , "\n";
	print leaf.Node?, "\n";
  print Depth(leaf), "\n";
  print Depth(node1), "\n";
  print Depth(node2), "\n";
  print Depth(root), "\n";
}
