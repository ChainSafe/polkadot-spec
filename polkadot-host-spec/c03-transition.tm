<TeXmacs|1.99.11>

<project|polkadot_host_spec.tm>

<style|<tuple|book|/home/anon/.TeXmacs/packages/algorithmacs-style.tx|algorithmacs-style>>

<\body>
  <chapter|State Transition><label|chap-state-transit>

  Like any transaction-based transition system, Polkadot state changes via
  executing an ordered set of instructions. These instructions are known as
  <em|extrinsics>. In Polkadot, the execution logic of the state-transition
  function is encapsulated in Runtime as defined in Definition
  <reference|defn-state-machine>. Runtime is presented as a Wasm blob in
  order to be easily upgradable. Nonetheless, the Polkadot Host needs to be
  in constant interaction with Runtime. The detail of such interaction is
  further described in Section <reference|sect-entries-into-runtime>.

  In Section <reference|sect-extrinsics>, we specify the procedure of the
  process where the extrinsics are submitted, pre-processed and validated by
  Runtime and queued to be applied to the current state.

  Polkadot, as with most prominent distributed ledger systems that make state
  replication feasible, journals and batches a series of extrinsics together
  in a structure known as a <em|block> before propagating to the other nodes.
  The specification of the Polkadot block as well as the process of verifying
  its validity are both explained in Section
  <reference|sect-state-replication>.

  <section|Interactions with Runtime><label|sect-entries-into-runtime>

  Runtime as defined in Definition <reference|defn-runtime> is the code
  implementing the logic of the chain. This code is decoupled from the
  Polkadot Host to make the Runtime easily upgradable without the need to
  upgrade the Polkadot Host itself. The general procedure to interact with
  Runtime is described in Algorithm <reference|algo-runtime-interaction>.

  <\algorithm>
    <label|algo-runtime-interaction><name|Interact-With-Runtime>(<math|F>:
    the runtime entry,\ 

    <math|H<rsub|b><around*|(|B|)>>: Block hash indicating the state at the
    end of <math|B>,\ 

    <math|A<rsub|1>,A<rsub|2>,\<ldots\>,A<rsub|n>>: arguments to be passed to
    the runtime entry)
  <|algorithm>
    <\algorithmic>
      <\state>
        <name|<math|\<cal-S\><rsub|B>\<leftarrow\>>Set-State-At(<math|H<rsub|b><around*|(|B|)>>)>
      </state>

      <\state>
        <math|A\<leftarrow\>Enc<rsub|SC><around*|(|<around*|(|A<rsub|1>,\<ldots\>,A<rsub|n>|)>|)>>
      </state>

      <\state>
        <math|<text|<name|Call-Runtime-Entry>><around*|(|R<rsub|B>,\<cal-R\>\<cal-E\><rsub|B>,F,A,A<rsub|len>|)>>
      </state>
    </algorithmic>
  </algorithm>

  In this section, we describe the details upon which the Polkadot Host is
  interacting with the Runtime. In particular, <name|Set-State-At> and
  <name|Call-Runtime-Entry> procedures called in Algorithm
  <reference|algo-runtime-interaction> are explained in Notation
  <reference|nota-call-into-runtime> and Definition
  <reference|defn-set-state-at> respectively. <math|R<rsub|B>> is the Runtime
  code loaded from <math|\<cal-S\><rsub|B>>, as described in Notation
  <reference|nota-runtime-code-at-state>, and
  <math|\<cal-R\>\<cal-E\><rsub|B>> is the Polkadot Host API, as described in
  Notation <reference|nota-re-api-at-state>.

  <subsection|Loading the Runtime Code \ \ ><label|sect-loading-runtime-code>

  The Polkadot Host expects to receive the code for the Runtime of the chain
  as a compiled WebAssembly (Wasm) Blob. The current runtime is stored in the
  state database under the key represented as a byte array:

  <\equation*>
    b\<assign\><text|3A,63,6F,64,65>
  </equation*>

  which is the byte array of ASCII representation of string \P:code\Q (see
  Section <reference|sect-genesis-block>). For any call to the Runtime, the
  Polkadot Host makes sure that it has the Runtime corresponding to the state
  in which the entry has been called. This is, in part, because the calls to
  Runtime have potentially the ability to change the Runtime code and hence
  Runtime code is state sensitive. Accordingly, we introduce the following
  notation to refer to the Runtime code at a specific state:

  <\notation>
    <label|nota-runtime-code-at-state>By <math|R<rsub|B>>, we refer to the
    Runtime code stored in the state storage whose state is set at the end of
    the execution of block <math|B>.
  </notation>

  The initial runtime code of the chain is embedded as an extrinsics into the
  chain initialization JSON file (representing the genesis state) and is
  submitted to the Polkadot Host (see Section
  <reference|sect-genesis-block>).

  Subsequent calls to the runtime have the ability to, in turn, call the
  storage API (see Section <reference|sect-re-api>) to insert a new Wasm blob
  into runtime storage slot to upgrade the runtime.

  <subsection|Code Executor>

  The Polkadot Host provides a Wasm Virtual Machine (VM) to run the Runtime.
  The Wasm VM exposes the Polkadot Host API to the Runtime, which, on its
  turn, executes a call to the Runtime entries stored in the Wasm module.
  This part of the Polkadot Host is referred to as the
  <em|<strong|Executor>.>

  Definition <reference|nota-call-into-runtime> introduces the notation for
  calling the runtime entry which is used whenever an algorithm of the
  Polkadot Host needs to access the runtime.

  <\notation>
    <label|nota-call-into-runtime> By

    <\equation*>
      <text|<name|Call-Runtime-Entry>><around*|(|R,\<cal-R\>\<cal-E\>,<text|<verbatim|Runtime-Entry>>,A,A<rsub|len>|)>
    </equation*>

    we refer to the task using the executor to invoke the
    <verbatim|Runtime-Entry> while passing an
    <math|A<rsub|1>,\<ldots\>,A<rsub|n>> argument to it and using the
    encoding described in Section <reference|sect-runtime-send-args-to-runtime-enteries>.
  </notation>

  In this section, we specify the general setup for an Executor call into the
  Runtime. In Section <reference|sect-runtime-entries> we specify the
  parameters and the return values of each Runtime entry separately.

  <subsubsection|Access to Runtime API>

  When the Polkadot Host calls a Runtime entry it should make sure Runtime
  has access to the all Polkadot Runtime API functions described in Appendix
  <reference|sect-runtime-entries>. This can be done for example by loading
  another Wasm module alongside the runtime which imports these functions
  from the Polkadot Host as host functions.

  <subsubsection|Sending Arguments to Runtime
  ><label|sect-runtime-send-args-to-runtime-enteries>

  In general, all data exchanged between the Polkadot Host and the Runtime is
  encoded using SCALE codec described in Section
  <reference|sect-scale-codec>. As a Wasm function, all runtime entries have
  the following identical signatures:

  \;

  <cpp|<verbatim|>(func $runtime_entry (param $data i32) (param $len i32)
  (result i64))>

  \;

  In each invocation of a Runtime entry, the argument(s) which are supposed
  to be sent to the entry, need to be encoded using SCALE codec into a byte
  array <math|B> using the procedure defined in Definition
  <reference|sect-scale-codec>.

  The Executor then needs to retrieve the Wam memory buffer of the Runtime
  Wasm module and extend it to fit the size of the byte array. Afterwards, it
  needs to copy the byte array <math|B> value in the correct offset of the
  extended buffer. Finally, when the Wasm method <verbatim|runtime_entry>,
  corresponding to the entry is invoked, two UINT32 integers are sent to the
  method as arguments. The first argument <verbatim|data> is set to the
  offset where the byte array <math|B> is stored in the Wasm the extended
  shared memory buffer. The second argument <verbatim|len> sets the length of
  the data stored in <math|B>., and the second one is the size of <math|B>.

  <subsubsection|The Return Value from a Runtime
  Entry><label|sect-runtime-return-value>

  The value which is returned from the invocation is an <verbatim|i64>
  integer, representing two consecutive <verbatim|i32> integers in which the
  least significant one indicates the pointer to the offset of the result
  returned by the entry encoded in SCALE codec in the memory buffer. The most
  significant one provides the size of the blob.

  <section|Extrinsics><label|sect-extrinsics>

  The block body consists of an array of extrinsics. In a broad sense,
  extrinsics are data from outside of the state which can trigger the state
  transition. This section describes the specifications of the extrinsics and
  their inclusion in the blocks.

  <subsection|Preliminaries>

  The extrinsics are divided in two main categories and defined as follows:

  <\definition>
    <strong|Transaction extrinsics> are extrinsics which are signed using
    either of the key types described in section
    <reference|sect-cryptographic-keys> and broadcasted between the nodes.
    <strong|Inherents extrinsics> are unsigned extrinsics which are generated
    by Polkadot Host and only included in the blocks produced by the node
    itself. They are broadcasted as part of the produced blocks rather than
    being gossiped as individual extrinsics.
  </definition>

  The Polkadot Host does not specify or limit the internals of each
  extrinsics and those are dealt with by the Runtime. From the Polkadot Host
  point of view, each extrinsics is simply a SCALE-encoded blob (see Section
  <reference|sect-scale-codec>).

  <subsection|Transactions>

  <subsubsection|Transaction Submission>

  Transaction submission is made by sending a <em|Transactions> network
  message. The structure of this message is specified in Section
  <reference|sect-msg-transactions>. Upon receiving a Transactions message,
  the Polkadot Host decodes and decouples the transactions and calls
  <verbatim|validate_trasaction> Runtime entry, defined in Section
  <reference|sect-rte-validate-transaction>, to check the validity of each
  received transaction. If <verbatim|validate_transaction> considers the
  submitted transaction as a valid one, the Polkadot Host makes the
  transaction available for the consensus engine for inclusion in future
  blocks.

  <subsection|Transaction Queue>

  A Block producer node should listen to all transaction
  messages<em|<index|Transaction Message>>. This is because the transactions
  are submitted to the node through the <em|transactions> network message
  specified in Section <reference|sect-msg-transactions>. Upon receiving a
  transactions message, the Polkadot Host separates the submitted
  transactions in the transactions message into individual transactions and
  passes them to the Runtime by executing Algorithm
  <reference|algo-validate-transactions> to validate and store them for
  inclusion into future blocks. To that aim, the Polkadot Host should keep a
  <em|transaction pool<index|transaction pool>> and a <em|transaction
  queue><index|transaction queue> defined as follows:

  <\definition>
    <label|defn-transaction-queue>The <strong|Transaction Queue> of a block
    producer node, formally referred to as <math|TQ> is a data structure
    which stores the transactions ready to be included in a block sorted
    according to their priorities (Definition
    <reference|sect-msg-transactions>). The <strong|Transaction Pool>,
    formally referred to as <math|TP>, is a hash table in which the Polkadot
    Host keeps the list of all valid transactions not in the transaction
    queue.
  </definition>

  Algorithm <reference|algo-validate-transactions> updates the transaction
  pool and the transaction queue according to the received message:

  <\algorithm|<label|algo-validate-transactions><name|Validate-Transactions-and-Store>(<math|M<rsub|T>:>Transaction
  Message)>
    <\algorithmic>
      <\state>
        <math|L\<leftarrow\>Dec<rsub|SC><around*|(|M<rsub|T>|)>>
      </state>

      <\state>
        <FOR-IN|<math|T>|<math|L >><strong|such that> <math|E\<nin\>TQ>
        <strong|and> <math|E\<nin\>TP>:
      </state>

      <\state>
        <math|B<rsub|d>\<leftarrow\>><name|Head(Longest-Chain((<math|BT>))>
      </state>

      <\state>
        <math|N\<leftarrow\>H<rsub|n><around*|(|B<rsub|d>|)>>
      </state>

      <\state>
        <math|R\<leftarrow\>><name|Call-Runtime-Entry><math|<around*|(|<text|<verbatim|TaggedTransactionQueue_validate_transaction>>,N,T|)>>
      </state>

      <\state>
        <\IF>
          <math|R> indicates <math|E> is <math|Valid:>
        </IF>
      </state>

      <\state>
        <\IF>
          <math|Requires>(R)\<subset\>
        </IF>

        <space|1em><math|<big|cup><rsub|\<forall\>T\<in\><around*|(|TQ|)>>><name|Provided-Tags>(T)
        \<cup\> <math|<big|cup><rsub|i\<less\>d,\<forall\>T,T\<in\>B<rsub|i>>><name|Provided-Tags(T)>:
      </state>

      <\state>
        <name|Insert-At(><math|TQ,T,Requires(R),Priority(R)>)<END>
      </state>

      <\state>
        <\ELSE>
          \;
        </ELSE>
      </state>

      <\state>
        <name|Add-To(TP,<math|T>)><END>
      </state>

      <\state>
        <name|Maintain-Transaction-Pool>
      </state>

      <\state>
        <\IF>
          Propagate(R)=<strong|True>:
        </IF>
      </state>

      <\state>
        <name|Propagate(><math|T>)<END><END><END>
      </state>
    </algorithmic>
  </algorithm>

  In which

  <\itemize-minus>
    <item><name|Longest-Chain> is defined in Definition
    <reference|defn-longest-chain>.

    <item><verbatim|TaggedTransactionQueue_validate_transaction> is a Runtime
    entry specified in Section <reference|sect-rte-validate-transaction> and
    Requires(R), Priority(R) and Propagate(R) refer to the corresponding
    fields in the tuple returned by the entry when it deems that <math|T> is
    valid.

    <item><name|Provided-Tags>(T) is the list of tags that transaction
    <math|T> provides. The Polkadot Host needs to keep track of tags that
    transaction <math|T> provides as well as requires after validating it.

    <item><name|Insert-At(><math|TQ,T,Requires(R),Priority(R)>) places
    <math|T> into <math|TQ> approperietly such that the transactions
    providing the tags which <math|T> requires or have higher priority than
    <math|T> are ahead of <math|T>.

    <item><name|Maintain-Transaction-Pool> is described in Algorithm
    <reference|algo-maintain-transaction-pool>.

    <item><name|Propagate(><math|T>) include <math|T> in the next
    <em|transactions message<index|Transaction Message>> sent to all peers of
    the Polkadot Host node.
  </itemize-minus>

  <\algorithm|<label|algo-maintain-transaction-pool><name|Maintain-Transaction-Pool>>
    <\algorithmic>
      <todo|This is scaning the pool for ready transactions and moving them
      to the TQ and dropping transactions which are not valid>
    </algorithmic>
  </algorithm>

  <subsubsection|Inherents>

  Block inherent data represents the totality of inherent extrinsics included
  in each block. This data is collected or generated by the Polkadot Host and
  handed to the Runtime for inclusion in the block. It's the responsability
  of the Polkadot Host implementation to keep track of those values. Table
  <reference|tabl-inherent-data> lists these inherent data, identifiers, and
  types. <todo|define uncles>

  <\big-table|<tabular|<tformat|<cwith|1|-1|1|-1|cell-tborder|0ln>|<cwith|1|-1|1|-1|cell-bborder|0ln>|<cwith|1|-1|1|-1|cell-lborder|0ln>|<cwith|1|-1|1|-1|cell-rborder|0ln>|<cwith|5|5|1|-1|cell-bborder|1ln>|<cwith|1|-1|1|1|cell-lborder|0ln>|<cwith|1|-1|3|3|cell-rborder|0ln>|<cwith|1|1|1|-1|cell-tborder|1ln>|<cwith|1|1|1|-1|cell-bborder|1ln>|<cwith|2|2|1|-1|cell-tborder|1ln>|<cwith|1|1|1|1|cell-lborder|0ln>|<cwith|1|1|3|3|cell-rborder|0ln>|<table|<row|<cell|Identifier>|<cell|Value
  type >|<cell|Description>>|<row|<cell|timstap0>|<cell|u64>|<cell|Unix epoch
  time in number of milliseconds>>|<row|<cell|babeslot>|<cell|u64>|<cell|Babe
  Slot Number<rsup|<reference|defn-epoch-slot>> of the current building
  block>>|<row|<cell|finalnum>|<cell|compact
  integer<math|<rsup|<reference|defn-sc-len-encoding>>>>|<cell|Header
  number<math|<rsup|<reference|defn-block-header>>> of the last finalized
  block>>|<row|<cell|uncles00>|<cell|array of block
  headers<math|<rsup|>>>|<cell|Provides a list of potential uncle block
  headers<math|<rsup|<reference|defn-block-header>>> for a given block>>>>>>
    <label|tabl-inherent-data>List of inherent data
  </big-table>

  <\definition>
    <label|defn-inherent-data><name|Inherent-Data >is a hashtable (Definition
    <reference|defn-scale-list>) representing the totality of inherent
    extrinsics included in each block. The entries of this hash table which
    are listed in Table <reference|tabl-inherent-data> are collected or
    generated by the Polkadot Host and then handed to the Runtime for
    inclusion as dercribed in Algorithm <reference|algo-build-block>. The
    identifiers are 8-byte values.
  </definition>

  <section|State Replication><label|sect-state-replication>

  Polkadot nodes replicate each other's state by syncing the history of the
  extrinsics. This, however, is only practical if a large set of transactions
  are batched and synced at the time. The structure in which the transactions
  are journaled and propagated is known as a block (of extrinsics) which is
  specified in Section <reference|sect-block-format>. Like any other
  replicated state machines, state inconsistency happens across Polkadot
  replicas. Section <reference|sect-managing-multiple-states> is giving an
  overview of how a Polkadot Host node manages multiple variants of the
  state.

  <subsection|Block Format><label|sect-block-format>

  In the Polkadot Host, a block is made of two main parts, namely the
  <with|font-shape|italic|block header> and the <with|font-shape|italic|list
  of extrinsics>. <em|The Extrinsics> represent the generalization of the
  concept of <em|transaction>, containing any set of data that is external to
  the system, and which the underlying chain wishes to validate and keep
  track of.

  <subsubsection|Block Header><label|block>

  The block header is designed to be minimalistic in order to boost the
  efficiency of the light clients. It is defined formally as follows:

  <\definition>
    <label|defn-block-header>The <strong|header of block B>,
    <strong|<math|Head<around|(|B|)>>> is a 5-tuple containing the following
    elements:

    <\itemize>
      <item><with|font-series|bold|<samp|parent_hash:>> is the 32-byte
      Blake2b hash (see Section <reference|sect-blake2>) of the header of the
      parent of the block indicated henceforth by
      <with|font-series|bold|mode|math|H<rsub|p>>.

      <item><strong|<samp|number:>> formally indicated as
      <strong|<math|H<rsub|i>>> is an integer, which represents the index of
      the current block in the chain. It is equal to the number of the
      ancestor blocks. The genesis state has number 0.

      <item><strong|<samp|state_root:>> formally indicated as
      <strong|<math|H<rsub|r>>> is the root of the Merkle trie, whose leaves
      implement the storage for the system.

      <item><strong|<samp|extrinsics_root:>> is the field which is reserved
      for the Runtime to validate the integrity of the extrinsics composing
      the block body. For example, it can hold the root hash of the Merkle
      trie which stores an ordered list of the extrinsics being validated in
      this block. The <samp|extrinsics_root> is set by the runtime and its
      value is opaque to the Polkadot Host. This element is formally referred
      to as <strong|<math|H<rsub|e>>>.

      <item><strong|<samp|digest:>> this field is used to store any
      chain-specific auxiliary data, which could help the light clients
      interact with the block without the need of accessing the full storage
      as well as consensus-related data including the block signature. This
      field is indicated as <strong|<math|H<rsub|d>>> and its detailed format
      is defined in Definition <reference|defn-digest>
    </itemize>
  </definition>

  <\definition>
    <label|defn-digest>The header <strong|digest> of block <math|B> formally
    referred to by <strong|<math|H<rsub|d><around*|(|B|)>>> is an array of
    <strong|digest items> <math|H<rsup|i><rsub|d>>'s , known as digest items
    of varying data type (see Definition <reference|defn-varrying-data-type>)
    such that

    <\equation*>
      H<rsub|d><around*|(|B|)>:=H<rsup|1><rsub|d>,\<ldots\>,H<rsup|n><rsub|d>
    </equation*>

    where each digest item can hold one of the type described in Table
    <reference|tabl-digest-items>:

    <\with|par-mode|center>
      <\small-table>
        \;

        <\center>
          <tabular*|<tformat|<cwith|1|-1|1|1|cell-halign|r>|<cwith|1|-1|3|3|cell-halign|l>|<cwith|1|-1|1|-1|cell-valign|c>|<cwith|1|-1|1|-1|cell-tborder|0ln>|<cwith|1|-1|1|-1|cell-bborder|0ln>|<cwith|1|-1|1|-1|cell-lborder|1ln>|<cwith|1|-1|1|-1|cell-rborder|1ln>|<cwith|5|5|1|-1|cell-bborder|1ln>|<cwith|1|-1|1|1|cell-lborder|1ln>|<cwith|1|1|1|-1|cell-tborder|1ln>|<cwith|1|1|1|-1|cell-bborder|1ln>|<cwith|2|2|1|-1|cell-tborder|1ln>|<cwith|1|1|1|1|cell-lborder|1ln>|<cwith|1|1|1|3|cell-halign|l>|<cwith|1|5|2|2|cell-halign|l>|<cwith|1|5|2|2|cell-valign|c>|<cwith|1|5|2|2|cell-tborder|0ln>|<cwith|1|5|2|2|cell-bborder|0ln>|<cwith|1|5|2|2|cell-lborder|1ln>|<cwith|1|5|2|2|cell-rborder|1ln>|<cwith|5|5|2|2|cell-bborder|1ln>|<cwith|1|5|2|2|cell-rborder|1ln>|<cwith|1|1|2|2|cell-tborder|1ln>|<cwith|1|1|2|2|cell-bborder|1ln>|<cwith|2|2|2|2|cell-tborder|1ln>|<cwith|1|1|2|2|cell-rborder|1ln>|<table|<row|<cell|Type
          Id>|<cell|Type name>|<cell|sub-components
          >>|<row|<cell|<math|2>>|<cell|Changes trie
          root>|<cell|<math|\<bbb-B\><rsub|32>>>>|<row|<cell|6>|<cell|Pre-Runtime>|<cell|<math|E<rsub|id>,\<bbb-B\>>>>|<row|<cell|4>|<cell|Consensus
          Message>|<cell|<math|E<rsub|id>,\<bbb-B\>>>>|<row|<cell|5>|<cell|Seal
          >|<cell|<math|E<rsub|id>,\<bbb-B\>>>>>>>
        </center>

        \;
      </small-table|<label|tabl-digest-items>The detail of the varying type
      that a digest item can hold.>
    </with>

    \;

    Where <math|E<rsub|id>> is the unique consensus engine identifier defined
    in Section <reference|sect-msg-consensus>. and

    <\itemize-dot>
      <item>[Future-reserved, currently not used] <strong|Changes trie root>
      contains the root of changes trie at block <math|B> as defined in
      section <reference|sect-changes-trie>.

      <item><strong|Pre-runtime> digest item represents messages produced by
      a consensus engine to the Runtime.

      <item><strong|Consensus> <with|font-series|bold|Message> digest item
      represents a message from the Runtime to the consensus engine (see
      Section <reference|sect-consensus-message-digest>).

      <item><strong|Seal> is the data produced by the consensus engine and
      proving the authorship of the block producer. In particular, the Seal
      digest item must be the last item in the digest array and must be
      stripped off before the block is submitted to the Runtime for
      validation and be added back to the digest afterward. The detail of the
      Seal digest item is laid out in Definition <reference|defn-babe-seal>.
    </itemize-dot>
  </definition>

  <\definition>
    <label|defn-block-header-hash>The <strong|Block Header Hash of Block
    <math|B>>, <strong|<math|H<rsub|h><around|(|B|)>>>, is the hash of the
    header of block <math|B> encoded by simple codec:\Q

    <\equation*>
      H<rsub|h><around|(|B|)>\<assign\>Blake2b<around|(|Enc<rsub|SC><around|(|Head<around|(|B|)>|)>|)>
    </equation*>
  </definition>

  <subsubsection|Justified Block Header><label|sect-justified-block-header>

  The Justified Block Header is provided by the consensus engine and
  presented to the Polkadot Host, for the block to be appended to the
  blockchain. It contains the following parts:

  <\itemize>
    <item><strong|<samp|<strong|block_header>>> the complete block header as
    defined in Section <reference|block> and denoted by
    <math|Head<around|(|B|)>>.

    <item><strong|<samp|justification>>: as defined by the consensus
    specification indicated by <math|Just<around|(|B|)>> <todo|link this to
    its definition from consensus>.

    <item><strong|<samp|authority Ids>>: This is the list of the Ids of
    authorities, which have voted for the block to be stored and<verbatim|>
    is formally referred to as <math|A<around|(|B|)>>. An authority Id is
    32bit.
  </itemize>

  <subsubsection|Block Body><label|sect-block-body>

  The Block Body consists of array extrinsics each encoded as a byte array.
  The internal of extrinsics is completely opaque to the Polkadot Host. As
  such, from the point of the Polkadot Host, and is simply a SCALE encoded
  array of byte arrays. Formally:

  <\definition>
    <label|defn-block-body>The <strong|body of Block> <math|B> represented as
    <strong|<math|Body<around*|(|B|)>>> is defined to be

    <\equation*>
      Body<around*|(|B|)>\<assign\>Enc<rsub|SC><around*|(|E<rsub|1>,\<ldots\>,E<rsub|n>|)>
    </equation*>

    Where each <math|E<rsub|i>\<in\>\<bbb-B\>> is a SCALE encoded extrinsic.
  </definition>

  <subsection|Block Submission><label|sect-block-submission>

  Block validation is the process by which the client asserts that a block is
  fit to be added to the blockchain. This means that the block is consistent
  with the world state and transitions from the state of the system to a new
  valid state.

  Blocks can be handed to the Polkadot Host both from the network stack for
  example by means of Block response network message (see Section
  <reference|sect-msg-block-response> ) and from the consensus engine.

  <subsection|Block Validation><label|sect-block-validation>

  Both the Runtime and the Polkadot Host need to work together to assure
  block validity. A block is deemed valid if the block author had the
  authorship right for the slot during which the slot was built as well as if
  the transactions in the block constitute a valid transition of states. The
  former criterion is validated by the Polkadot Host according to the block
  production consensus protocol. The latter can be verified by the Polkadot
  Host invoking <verbatim|execute_block> entry into the Runtime as a part of
  the validation process.

  \;

  The Polkadot Host implements the following procedure to assure the validity
  of the block:

  <\algorithm|<label|algo-import-and-validate-block><name|Import-and-Validate-Block(<math|B,Just<around|(|B|)>>)>>
    <\algorithmic>
      <\state>
        <name|Set-Storage-State-At(<math|P<around*|(|B|)>>)>
      </state>

      <\state>
        <\IF>
          <math|Just<around|(|B|)>\<neq\>\<emptyset\>>
        </IF>
      </state>

      <\state>
        <name|Verify-Block-Justification><math|<around|(|B,Just<around|(|B|)>|)>>
      </state>

      <\state>
        <\IF>
          <math|B> <strong|is> Finalized <strong|and> <math|P<around*|(|B|)>>
          <strong|is not> Finalized
        </IF>
      </state>

      <\state>
        <name|Mark-as-Final><math|<around*|(|P<around*|(|B|)>|)>><END><END>
      </state>

      <\state>
        <\IF>
          <math|H<rsub|p><around|(|B|)>\<nin\>PBT>
        </IF>
      </state>

      <\state>
        <\RETURN>
          <END>
        </RETURN>
      </state>

      <\state>
        <name|Verify-Authorship-Right>(<math|Head<around*|(|B|)>>)
      </state>

      <\state>
        <math|S\<leftarrow\>> <name|Call-Runtime-Entry><math|<around*|(|<text|<verbatim|Core_execute_block>>,B|)>>
      </state>
    </algorithmic>
  </algorithm>

  For the definition of the finality and the finalized block see Section
  <reference|sect-finality>. <math|PBT> is the pruned block tree defined in
  Definition <reference|defn-block-tree>. <name|Verify-Authorship-Right> is
  part of the block production consensus protocol and is described in
  Algorithm <reference|algo-verify-authorship-right>.

  <subsection|Managaing Multiple Variants of
  State><label|sect-managing-multiple-states>

  Unless a node is committed to only update its state according to the
  finalized block (See Definition <reference|defn-finalized-block>), it is
  inevitable for the node to store multiple variants of the state (one for
  each block). This is, for example, necessary for nodes participating in the
  block production and finalization.

  While the state trie structure described in Section
  <reference|sect-state-storage-trie-structure> facilitates and optimizes
  storing and switching between multiple variants of the state storage, the
  Polkadot Host does not specify how a node is required to accomplish this
  task. Instead, the Polkadot Host is required to implement
  <name|Set-State-At> operation which behaves as defined in Definition
  <reference|defn-set-state-at>:

  <\definition>
    <label|defn-set-state-at>The function

    <\equation*>
      <text|<name|<strong|Set-State-At(<math|\<b-B\>>)>>>
    </equation*>

    \ in which <math|B> is a block in the block tree (See Definition
    <reference|defn-block-tree>), sets the content of state storage equal to
    the resulting state of executing all extrinsics contained in the branch
    of the block tree from genesis till block B including those recorded in
    Block B.
  </definition>

  For the definition of the state storage see Section
  <reference|sect-state-storage>.

  <subsection|Changes Trie><label|sect-changes-trie>

  Polkadot focuses on light client friendliness and therefore implements
  functionalities which allows identifying changes in the blockchain without
  requiring to search through the entire chain. The <strong|Changes Trie> is
  a radix-16 tree datastructure as defined in Definition
  <reference|defn-radix-tree> and maintained by the Polkadot node. It stores
  multiple kinds of storage changes made by every block. The primary method
  of generating the Changes Trie is by calling the
  <verbatim|ext_storage_changes_root> Host API as described in section
  <reference|sect-ext-storage-changes-root>. In order to provide this API
  function, it is imperative that the Polkadot Host implements a mechanism to
  keep track of the changes created by individual blocks, as mentioned in
  section <reference|sect-state-storage>.

  \;

  The Changes Trie stores three different types of changes. The inserted
  key-value pair in the Changes Trie is formally defined as:

  <\equation*>
    <around*|(|A<rsub|Type>,H<rsub|i><around*|(|B<rsub|i>|)>,K|)>\<rightarrow\>A<rsub|Value>
  </equation*>

  where <math|K> is the changed storage key,
  <math|H<rsub|i><around*|(|B<rsub|i>|)>> refers to the block number at which
  this key has been inserted (current block) into the Changes Trie and
  <math|A<rsub|Type>> is a varying datatype as defined in Definition
  <reference|defn-varrying-data-type>. The type including its corresponding
  value is defined in table <reference|table-changes-trie-key-types>.<htab|5mm>

  <\big-table>
    <tabular|<tformat|<cwith|2|2|1|-1|cell-bborder|0ln>|<cwith|4|4|1|-1|cell-tborder|1ln>|<cwith|4|4|1|-1|cell-bborder|0ln>|<cwith|5|5|1|-1|cell-tborder|1ln>|<cwith|5|5|1|-1|cell-bborder|1ln>|<cwith|5|5|1|1|cell-lborder|0ln>|<cwith|5|5|3|3|cell-rborder|0ln>|<cwith|1|1|1|-1|cell-tborder|1ln>|<cwith|1|1|1|-1|cell-bborder|1ln>|<cwith|2|2|1|-1|cell-tborder|1ln>|<cwith|1|1|1|1|cell-lborder|0ln>|<cwith|1|1|3|3|cell-rborder|0ln>|<table|<row|<cell|<strong|Type>>|<cell|<strong|Description>>|<cell|<strong|Value>>>|<row|<cell|1>|<cell|Pair
    between storage key and extrinsics>|<cell|<math|<around*|{|e<rsub|i>,\<ldots\>,e<rsub|n>|}>>>>|<row|<cell|>|<cell|<text-dots>
    where <math|e<rsub|i> refers to the >indice of the extrinsic within the
    block>|<cell|>>|<row|<cell|2>|<cell|Pair between storage key and block
    numbers>|<cell|<math|<around*|{|H<rsub|i><around*|(|B<rsub|n>|)>,\<ldots\>,H<rsub|i><around*|(|B<rsub|m>|)>|}>>>>|<row|<cell|3>|<cell|Pair
    between storage key and Child Changes
    Trie>|<cell|Child-Changes-Trie-Root>>>>>

    \;
  <|big-table>
    <label|table-changes-trie-key-types>Possible types of keys of mappings in
    the Changes Trie
  </big-table>

  <strong|Note>: Unlike the default encoding for varying data types, this
  structure starts its indexing at <verbatim|1>.

  \;

  The Changes Trie itself is not part of the block, but a separately
  maintained database by the Polkadot Host. The Merkle proof of the Changes
  Trie must be inlcuded in the block digest as described in Definition
  <reference|defn-digest> and gets calculated as described in section
  <reference|sect-merkl-proof>. The root calculation only applies to pairs
  which were generated on the individual block and does not consider pairs
  from previous blocks.

  \;

  <todo|This seperately maintained database by the Polkadot Host is intended
  to be used by \Pproof servers\Q, where its implementation and behavior has
  not been fully implemented and specified yet. This is considered
  future-reserved>

  \;

  As clarified in the individual sections of each type, not all of those
  types get generated on every block. But if conditions apply, all those
  different types of pairs get inserted into the same Changes Trie, therefore
  only one Changes Trie Root gets generated for each block.

  <subsubsection|Key to extrinsics pairs>

  This key-value pair stores changes which occure in an individual block. Its
  value is a SCALE encoded array containing the indices of the extrnsics that
  caused any changes to the specified key. The key-value pair is defined as:

  <\equation*>
    <around*|(|1,H<rsub|i><around*|(|B<rsub|i>|)>,K|)>\<rightarrow\><around*|{|e<rsub|i>,\<ldots\>,e<rsub|n>|}>
  </equation*>

  The indices are unsigned 32-bit integers and their values are based on the
  order in which each extrnsic appears in the block (starting at 0). The
  Polkadot Host generates those pairs for every changed key on each and every
  block.

  \;

  <todo|clarify special key value of 0xffffffff>

  <subsubsection|Key to block pairs>

  This key-value pair stores changes which occured in a certain range of
  blocks. Its value is a SCALE encoded array containing block numbers where
  extrinsics caused any changes to the specified key. The key-value pair is
  defined as:

  <\equation*>
    <around*|(|2,H<rsub|i><around*|(|B<rsub|i>|)>,K|)>\<rightarrow\><around*|{|H<rsub|i><around*|(|B<rsub|n>|)>,\<ldots\>,H<rsub|i><around*|(|B<rsub|m>|)>|}>
  </equation*>

  The block numbers are represented as unsigned 32-bit integers. The Polkadot
  Host does <strong|not> generate those pairs on every block. The genesis
  states contains the key <verbatim|:changes_trie> where its unsigned 64-bit
  value represents two 32-bit integers:

  <\itemize-dot>
    <item><verbatim|interval> - The interval (in blocks) at which those pairs
    should be created. If this value is less or equal to 1 it means that
    those pairs are not created at all.

    <item><verbatim|levels> - The maximum number of \Plevels\Q in the
    hierarchy. If this value is 0 it means that those pairs are not created
    at all.
  </itemize-dot>

  For each level from 1 to <verbatim|levels>, the Polkadot Host creates those
  pairs for on every <verbatim|<math|<text|interval<rsup|level><verbatim|>>>>-nth
  block, formally applied as:

  <\algorithm|<name|Key-To-Block-Pairs>(<math|B<rsub|i>>, interval, levels)>
    <strong|Initialize:>

    1. <math|I=interval>

    2. <math|L=levels>

    <strong|for each> <math|l\<in\><around*|{|1,\<ldots\>,L|}>>

    3.<space|1em>if <math|H<rsub|i><around*|(|B<rsub|i>|)>=I<rsup|l>>

    4.<space|2em><name|Insert-Blocks>(<math|H<rsub|i><around*|(|B<rsub|i>|)>>,
    <math|I<rsup|l>>)
  </algorithm>

  <\itemize-dot>
    <item><name|Insert-Blocks> - Inserts every block number within the range
    <math|H<rsub|i><around*|(|B<rsub|i>|)>-I<rsup|l>+1> to <math|H<rsub|i>>
    where any extrinsic changed the specified key.
  </itemize-dot>

  For example, let's say <verbatim|interval> is set at <verbatim|4> and
  <verbatim|levels> is set at <verbatim|3>. This means there are now three
  levels which get generated at occurences:

  <\enumerate-numeric>
    <item><strong|Level 1> - Those pairs are generated at every
    <math|<text|<strong|4<rsup|1>>>>-nth block, where the pair value contains
    the block numbers of every block that changed the specified storage key.
    This level only considers block numbers of the last four
    (<math|4<rsup|1>>) blocks.

    \;

    Example: this level occurs at block 4, 8, 12, 16, 32, etc.

    <item><strong|Level 2> - Those pairs are generated at every
    <math|<text|<strong|4<rsup|2> >>>-nth block, where the pair value
    contains the block numbers of every block that changed the specified
    storage key. This level only considers block numbers of the last 16
    (<math|4<rsup|2>>) blocks.

    \;

    Example: this level occurs at block 16, 32, 64, 128, 256, etc.

    <item><strong|Level 3> - Those pairs are generated at every
    <text|<math|<text|<strong|4<rsup|3>>>>>-nth block, where the pair value
    contains the block numbers of every block that changed the specified
    storage key. this level only considers block number of the last 64
    (<math|4<rsup|3>>) blocks.

    \;

    Example: this level occurs at block 64, 128, 196, 256, 320, etc.
  </enumerate-numeric>
</body>

<\initial>
  <\collection>
    <associate|chapter-nr|2>
    <associate|page-first|23>
    <associate|page-height|auto>
    <associate|page-type|letter>
    <associate|page-width|auto>
    <associate|section-nr|1<uninit>>
    <associate|subsection-nr|4>
  </collection>
</initial>

<\references>
  <\collection>
    <associate|algo-import-and-validate-block|<tuple|3.4|?>>
    <associate|algo-maintain-transaction-pool|<tuple|3.3|?>>
    <associate|algo-runtime-interaction|<tuple|3.1|?>>
    <associate|algo-validate-transactions|<tuple|3.2|?>>
    <associate|auto-1|<tuple|3|?>>
    <associate|auto-10|<tuple|3.2.2|?>>
    <associate|auto-11|<tuple|3.2.2.1|?>>
    <associate|auto-12|<tuple|3.2.3|?>>
    <associate|auto-13|<tuple|3.2.3|?>>
    <associate|auto-14|<tuple|3.2.3|?>>
    <associate|auto-15|<tuple|3.2.3|?>>
    <associate|auto-16|<tuple|<with|mode|<quote|math>|<rigid|->>|?>>
    <associate|auto-17|<tuple|3.2.3.1|?>>
    <associate|auto-18|<tuple|3.1|?>>
    <associate|auto-19|<tuple|3.3|?>>
    <associate|auto-2|<tuple|3.1|?>>
    <associate|auto-20|<tuple|3.3.1|?>>
    <associate|auto-21|<tuple|3.3.1.1|?>>
    <associate|auto-22|<tuple|3.2|?>>
    <associate|auto-23|<tuple|3.3.1.2|?>>
    <associate|auto-24|<tuple|3.3.1.3|?>>
    <associate|auto-25|<tuple|3.3.2|?>>
    <associate|auto-26|<tuple|3.3.3|?>>
    <associate|auto-27|<tuple|3.3.4|?>>
    <associate|auto-28|<tuple|3.3.5|?>>
    <associate|auto-29|<tuple|3.3|?>>
    <associate|auto-3|<tuple|3.1.1|?>>
    <associate|auto-30|<tuple|3.3.5.1|?>>
    <associate|auto-31|<tuple|3.3.5.2|?>>
    <associate|auto-4|<tuple|3.1.2|?>>
    <associate|auto-5|<tuple|3.1.2.1|?>>
    <associate|auto-6|<tuple|3.1.2.2|?>>
    <associate|auto-7|<tuple|3.1.2.3|?>>
    <associate|auto-8|<tuple|3.2|?>>
    <associate|auto-9|<tuple|3.2.1|?>>
    <associate|block|<tuple|3.3.1.1|?>>
    <associate|chap-state-transit|<tuple|3|?>>
    <associate|defn-block-body|<tuple|3.9|?>>
    <associate|defn-block-header|<tuple|3.6|?>>
    <associate|defn-block-header-hash|<tuple|3.8|?>>
    <associate|defn-digest|<tuple|3.7|?>>
    <associate|defn-inherent-data|<tuple|3.5|?>>
    <associate|defn-set-state-at|<tuple|3.10|?>>
    <associate|defn-storage-key-to-blocks|<tuple|3.11|?>>
    <associate|defn-storage-key-to-child-tries|<tuple|3.11|?>>
    <associate|defn-storage-key-to-extrinsics|<tuple|3.11|?>>
    <associate|defn-transaction-queue|<tuple|3.4|?>>
    <associate|nota-call-into-runtime|<tuple|3.2|?>>
    <associate|nota-runtime-code-at-state|<tuple|3.1|?>>
    <associate|sect-block-body|<tuple|3.3.1.3|?>>
    <associate|sect-block-format|<tuple|3.3.1|?>>
    <associate|sect-block-submission|<tuple|3.3.2|?>>
    <associate|sect-block-validation|<tuple|3.3.3|?>>
    <associate|sect-changes-trie|<tuple|3.3.5|?>>
    <associate|sect-entries-into-runtime|<tuple|3.1|?>>
    <associate|sect-extrinsics|<tuple|3.2|?>>
    <associate|sect-justified-block-header|<tuple|3.3.1.2|?>>
    <associate|sect-loading-runtime-code|<tuple|3.1.1|?>>
    <associate|sect-managing-multiple-states|<tuple|3.3.4|?>>
    <associate|sect-runtime-return-value|<tuple|3.1.2.3|?>>
    <associate|sect-runtime-send-args-to-runtime-enteries|<tuple|3.1.2.2|?>>
    <associate|sect-state-replication|<tuple|3.3|?>>
    <associate|tabl-digest-items|<tuple|3.2|?>>
    <associate|tabl-inherent-data|<tuple|3.1|?>>
    <associate|table-changes-trie-key-types|<tuple|3.3|?>>
  </collection>
</references>

<\auxiliary>
  <\collection>
    <\associate|idx>
      <tuple|<tuple|Transaction Message>|<pageref|auto-13>>

      <tuple|<tuple|transaction pool>|<pageref|auto-14>>

      <tuple|<tuple|transaction queue>|<pageref|auto-15>>

      <tuple|<tuple|Transaction Message>|<pageref|auto-16>>
    </associate>
    <\associate|table>
      <tuple|normal|<\surround|<hidden-binding|<tuple>|3.1>|>
        List of inherent data
      </surround>|<pageref|auto-18>>

      <tuple|normal|<surround|<hidden-binding|<tuple>|3.2>||The detail of the
      varying type that a digest item can hold.>|<pageref|auto-22>>

      <tuple|normal|<\surround|<hidden-binding|<tuple>|3.3>|>
        Possible types of keys of mappings in the Changes Trie
      </surround>|<pageref|auto-29>>
    </associate>
    <\associate|toc>
      <vspace*|1fn><with|font-series|<quote|bold>|math-font-series|<quote|bold>|3<space|2spc>State
      Transition> <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-1><vspace|0.5fn>

      3.1<space|2spc>Interactions with Runtime
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-2>

      <with|par-left|<quote|1tab>|3.1.1<space|2spc>Loading the Runtime Code
      \ \ \ <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-3>>

      <with|par-left|<quote|1tab>|3.1.2<space|2spc>Code Executor
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-4>>

      <with|par-left|<quote|2tab>|3.1.2.1<space|2spc>Access to Runtime API
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-5>>

      <with|par-left|<quote|2tab>|3.1.2.2<space|2spc>Sending Arguments to
      Runtime \ <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-6>>

      <with|par-left|<quote|2tab>|3.1.2.3<space|2spc>The Return Value from a
      Runtime Entry <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-7>>

      3.2<space|2spc>Extrinsics <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-8>

      <with|par-left|<quote|1tab>|3.2.1<space|2spc>Preliminaries
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-9>>

      <with|par-left|<quote|1tab>|3.2.2<space|2spc>Transactions
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-10>>

      <with|par-left|<quote|2tab>|3.2.2.1<space|2spc>Transaction Submission
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-11>>

      <with|par-left|<quote|1tab>|3.2.3<space|2spc>Transaction Queue
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-12>>

      <with|par-left|<quote|2tab>|3.2.3.1<space|2spc>Inherents
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-17>>

      3.3<space|2spc>State Replication <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-19>

      <with|par-left|<quote|1tab>|3.3.1<space|2spc>Block Format
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-20>>

      <with|par-left|<quote|2tab>|3.3.1.1<space|2spc>Block Header
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-21>>

      <with|par-left|<quote|2tab>|3.3.1.2<space|2spc>Justified Block Header
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-23>>

      <with|par-left|<quote|2tab>|3.3.1.3<space|2spc>Block Body
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-24>>

      <with|par-left|<quote|1tab>|3.3.2<space|2spc>Block Submission
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-25>>

      <with|par-left|<quote|1tab>|3.3.3<space|2spc>Block Validation
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-26>>

      <with|par-left|<quote|1tab>|3.3.4<space|2spc>Managaing Multiple
      Variants of State <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-27>>

      <with|par-left|<quote|1tab>|3.3.5<space|2spc>Changes Trie
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-28>>

      <with|par-left|<quote|2tab>|3.3.5.1<space|2spc>Key to extrinsics pairs
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-30>>

      <with|par-left|<quote|2tab>|3.3.5.2<space|2spc>Key to block pairs
      <datoms|<macro|x|<repeat|<arg|x>|<with|font-series|medium|<with|font-size|1|<space|0.2fn>.<space|0.2fn>>>>>|<htab|5mm>>
      <no-break><pageref|auto-31>>
    </associate>
  </collection>
</auxiliary>