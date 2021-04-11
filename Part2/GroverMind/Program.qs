namespace Qrng {
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Random;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Diagnostics;
    
// Functions____________________________________________________________________________________________

    function Convert(inputs : Bool[]) : Int[] {
        //Converts from array of couples of bits to array of integers.
        mutable converted = new Int[5];
        let chunks = Chunks(2,inputs);
        for i in 0 .. Length(inputs)/2-1 {
            set converted w/= i <- BoolArrayAsInt(chunks[i]);
        }
        return converted;
    }

    function Compare(master : Int[], player : Int[]) : (Bool,Int)[] {
        //Compares the two sequences of colors.
        //For each position in the grid, returns a tuple containing a boolean (true if the colors are matching,
        //false otherwise) and the color of the player sequence.
        mutable check = new (Bool,Int)[5];
        for i in 0 .. 4 {
            let control = master[i] == player[i];
            set check w/= i <- (control, player[i]);
            }   
        return check;
    }

    function AllAreTrue(arr : (Bool,Int)[]) : Bool { 
        //Returns a true if the array of tuples in input contains all trues in the first entry
        mutable count = 0; 

        for i in 0..Length(arr)-1{ 
            let (guess, col) = arr[i];
            if guess{ 
                set count = count +1; 
            } 
        } 
        let check = count == Length(arr); 
        return check; 
    }

    function CountHowManyTrue(arr : (Bool,Int)[]) : Int { 
        //Returns a the number of trues in the array of tuples
        mutable count = 0; 

        for i in 0..Length(arr)-1{ 
            let (guess, col) = arr[i];
            if guess{ 
                set count = count +1; 
            } 
        } 
        return count;
    }

    function Colorify(input: Int[]) : String[] {
        //Returns the array of colours given an array of integers
        mutable converted = new String[Length(input)];
        let colours = ["Red","Green","Blue","Yellow"];
        for i in 0 .. Length(input)-1{
            set converted w/=i <- colours[input[i]];
        }
        return converted;
    }

// Operations____________________________________________________________________________________________

    operation InitialSequence() : Int[] {
        //Generates a sequence of colours
        let cycles = 5;
        let nColors = 4;
        mutable arr1 = new Int[cycles];
        for i in 0 .. cycles-1{
            set arr1 w/= i <- DrawRandomInt(0,nColors-1);
        }
        return arr1;
    }

    operation MarkMatchingColors(input : Qubit[], check : (Bool,Int)[], target : Qubit) : Unit is Adj {
        //GroverMind oracle
        let register_chunk = Chunks(2,input);
        use controlQubit = Qubit[Length(input)/2];
        within {
            for ((guess, col), (Q, control)) in Zipped(check, Zipped(register_chunk, controlQubit)){
                if guess{
                    ControlledOnInt(col,X)(Q,control);
                }
                else {
                    X(control); 
                }
            }
        } apply {
            Controlled X(controlQubit, target);
        }
    }

    operation ApplyMarkingOracleAsPhaseOracle(
        //From Marking to Phase Oracle by means of a phase kickback
        MarkingOracle : ((Qubit[], Qubit) => Unit is Adj), 
        register : Qubit[]
    ) : Unit is Adj {
        use target = Qubit();
        within {
            X(target);
            H(target);
        } apply {
            MarkingOracle(register, target);
        }
    }

    operation RunGroversSearch(register : Qubit[], phaseOracle : ((Qubit[]) => Unit is Adj), iterations : Int) : Unit {
        //Grover's algorithm iteration for the optimal number of times
        ApplyToEach(H, register);
        for i in 1 .. iterations {
            phaseOracle(register);
            within {
                ApplyToEachA(H, register);
                ApplyToEachA(X, register);
            } apply {
                Controlled Z(Most(register), Tail(register));
            }
        }
        
    }

    @EntryPoint()
    operation QasterMind() : Unit {
        //GroverMind's main core 
        let nQubits = 10;

        let master_sequence = InitialSequence();                                 
        let player_sequence = InitialSequence();                                 

        mutable well_done = Compare(master_sequence, player_sequence);           
        mutable guessed = CountHowManyTrue(well_done);
        mutable nIterations = Round(PI()  * PowD(2.,  IntAsDouble(guessed) - 2. ));   
        mutable answer = new Bool[nQubits];
        mutable iter = 0;

        use (register, output) = (Qubit[nQubits], Qubit());

        repeat{
            let MarkingOracle = MarkMatchingColors(_,well_done,_);
            let PhaseOracle = ApplyMarkingOracleAsPhaseOracle(MarkingOracle,_);
            RunGroversSearch(register, PhaseOracle, nIterations);
            
            let res = MultiM(register);

            set answer = ResultArrayAsBoolArray(res);
            set well_done = Compare(master_sequence, Convert(answer));

            Message($"\n=======================================================");
            Message($"ITERATION {iter+1}:");
            Message($"Master sequence: {Colorify(master_sequence)}");
            Message($"Player guess: {Colorify(Convert(answer))}");

            ResetAll(register);

        } until AllAreTrue(well_done)
        fixup{
            set guessed = CountHowManyTrue(well_done);
            set nIterations = Round(PI()  * PowD(2.,  IntAsDouble(guessed) - 2. ));
            set iter+=1;
        }

        Message($"\n\nFantastico :D GroverMind found the solution in {iter+1} iterations!");
    }
}

    
    
