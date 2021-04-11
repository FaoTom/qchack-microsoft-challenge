namespace QCHack.Task4 {
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Logical;
    open Microsoft.Quantum.Diagnostics;

    // Task 4 (12 points). f(x) = 1 if the graph edge coloring is triangle-free
    // 
    // Inputs:
    //      1) The number of vertices in the graph "V" (V ≤ 6).
    //      2) An array of E tuples of integers "edges", representing the edges of the graph (0 ≤ E ≤ V(V-1)/2).
    //         Each tuple gives the indices of the start and the end vertices of the edge.
    //         The vertices are indexed 0 through V - 1.
    //         The graph is undirected, so the order of the start and the end vertices in the edge doesn't matter.
    //      3) An array of E qubits "colorsRegister" that encodes the color assignments of the edges.
    //         Each color will be 0 or 1 (stored in 1 qubit).
    //         The colors of edges in this array are given in the same order as the edges in the "edges" array.
    //      4) A qubit "target" in an arbitrary state.
    //
    // Goal: Implement a marking oracle for function f(x) = 1 if
    //       the coloring of the edges of the given graph described by this colors assignment is triangle-free, i.e.,
    //       no triangle of edges connecting 3 vertices has all three edges in the same color.
    //
    // Example: a graph with 3 vertices and 3 edges [(0, 1), (1, 2), (2, 0)] has one triangle.
    // The result of applying the operation to state (|001⟩ + |110⟩ + |111⟩)/√3 ⊗ |0⟩ 
    // will be 1/√3|001⟩ ⊗ |1⟩ + 1/√3|110⟩ ⊗ |1⟩ + 1/√3|111⟩ ⊗ |0⟩.
    // The first two terms describe triangle-free colorings, 
    // and the last term describes a coloring where all edges of the triangle have the same color.
    //
    // In this task you are not allowed to use quantum gates that use more qubits than the number of edges in the graph,
    // unless there are 3 or less edges in the graph. For example, if the graph has 4 edges, you can only use 4-qubit gates or less.
    // You are guaranteed that in tests that have 4 or more edges in the graph the number of triangles in the graph 
    // will be strictly less than the number of edges.
    //
    // Hint: Make use of helper functions and helper operations, and avoid trying to fit the complete
    //       implementation into a single operation - it's not impossible but make your code less readable.
    //       GraphColoring kata has an example of implementing oracles for a similar task.
    //
    // Hint: Remember that you can examine the inputs and the intermediary results of your computations
    //       using Message function for classical values and DumpMachine for quantum states.
    //
    operation MarkEqualColors(inputs : Qubit[], output : Qubit) : Unit is Adj+Ctl {
        within{
            CNOT(inputs[0],inputs[1]);
            CNOT(inputs[0],inputs[2]);
            ApplyToEachA(X,inputs[1..2]);
       }
       apply{
           CCNOT(inputs[1],inputs[2],output);
       }
       
    }

    function isTriangle( edge1 : (Int, Int), edge2 : (Int, Int), edge3 : (Int, Int)) : Bool{
        
        let (start1,stop1) = edge1;
        let (start2,stop2) = edge2;
        let (start3,stop3) = edge3;

        let vertices = [start1,start2,start3,stop1,stop2,stop3];
        let un_sort_vertices = Unique(EqualI,Sorted(LessThanOrEqualI,vertices));

        let size = Length(un_sort_vertices);

        if size == 3 { 
            return true;
        }
        else{
            return false;
        }


    }

    function TripletsList(edges : (Int, Int)[]): (Int,Int,Int)[] {
        
        let nEdges = Length(edges);

        let nCombinations = nEdges*(nEdges-1)*(nEdges-2)/6;

        mutable triplets = new (Int,Int,Int)[nCombinations];

        mutable count = 0;
    
        for i in 0..nEdges-3{
            for j in i+1..nEdges-2{
                for k in j+1..nEdges-1{
                    set triplets w/= count <- (i,j,k);
                    set count = count + 1;
                }
            }
        }
        return triplets;

    }

    function TriangleList (trList : (Int,Int,Int)[], edges : (Int, Int)[]) : (Int,Int,Int)[]{
        
        let nCombinations = Length(trList);
        mutable triangleCounter = 0;
        mutable iftriangle = new Bool[nCombinations];
        
        for i in 0..nCombinations-1{
            let (n1,n2,n3) = trList[i];
            let sides = (edges[n1],edges[n2],edges[n3]);
            let boolTriangle = isTriangle(sides);
            set iftriangle w/= i <- boolTriangle;
            if(boolTriangle){
                set triangleCounter = triangleCounter + 1;

            }
        }   

        mutable trianglelist = new (Int,Int,Int)[triangleCounter];
        
        mutable indexCount = 0;

        for i in 0..nCombinations-1{
            if(iftriangle[i]){
                set trianglelist w/= indexCount <- trList[i];
                set indexCount = indexCount+1;
            }
            

        }
                
        return trianglelist;

    }

    operation Task4_TriangleFreeColoringOracle (
        V : Int, 
        edges : (Int, Int)[], 
        colorsRegister : Qubit[], 
        target : Qubit
    ) : Unit is Adj+Ctl {
        
        let nEdges = Length(edges); 

        let trList = TripletsList(edges);
        //Message("TripletsList done");
        let triangleList = TriangleList(trList,edges);
        //Message("TriangleList done");
        let nTriangles = Length(triangleList);

        use conflictQubits = Qubit[nTriangles];


        within{
            for (sideTuple,conflictQubit) in Zipped(triangleList,conflictQubits){
                let(side1,side2,side3)=sideTuple;

                MarkEqualColors([colorsRegister[side1],colorsRegister[side2],colorsRegister[side3]],conflictQubit);
                //Message("Filter done");
            }
        }
        apply{
            (ControlledOnInt(0,X))(conflictQubits, target);
            //Message("Marking done");
        }

        //Message("Done");
                
    }
}

