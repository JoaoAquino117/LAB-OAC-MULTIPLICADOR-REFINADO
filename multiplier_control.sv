// multiplier_control.sv
// FSM de controle da versao refinada do multiplicador
//
// Fluxograma da versao refinada (uma iteracao por ciclo):
//
//   1. Testar Product[0] (LSB do registrador product, equivale ao Multiplier0)
//   2. Se Product[0] == 1 ? Product[63:32] = Product[63:32] + Multiplicand
//      (passos 1 e 2 combinados com o shift no mesmo ciclo)
//   3. Shift Product a direita 1 bit (carry do passo 2 vai para Product[63])
//   4. 32a. repeticao? ? Sim: Fim | Nao: voltar ao passo 1
//
// Diferenças em relacao a versao original:
//   - Estados ADD_OR_SKIP e SHIFT fundidos em COMPUTE (add + shift em 1 ciclo)
//   - multiplier_lsb nao e mais exposto pela FSM (testado internamente no datapath)
//   - product_wr e shift_en substituidos por compute_en
//   - Total: ~34 ciclos (1 LOAD + 32 COMPUTE + 1 DONE)
//      vs. ~66 ciclos da versao original (1 LOAD + 32×2 + 1 DONE)
//
// Estados:
//   IDLE    ? aguarda sinal 'start'
//   LOAD    ? carrega operandos no datapath (1 ciclo)
//   COMPUTE ? executa uma iteracao add+shift; repete 32 vezes (count 0..31)
//   DONE    ? sinaliza conclusao; retorna a IDLE quando 'start' é resetado

module multiplier_control (
    input  logic clk,
    input  logic rst_n,

    // Interface com o usuario
    input  logic start,
    output logic done,

    // Interface com o datapath
    output logic load,        // Carrega operandos iniciais
    output logic compute_en   // Executa uma iteracao (add condicional + shift)
);

    // Implemente o modulo aqui
    
    // Definicao dos Estados da FSM
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        LOAD    = 2'b01,
        COMPUTE = 2'b10,
        DONE    = 2'b11
    } state_t;

    state_t state, next_state;
    logic [5:0] count; // Contador para controlar as 32 iteracoes

    // Bloco Sequencial: Atualiza o Estado e o Contador
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 6'd0;
        end else begin
            state <= next_state;
            
            // Logica do contador
            if (state == LOAD) begin
                count <= 6'd0; // Zera o contador na preparacao
            end else if (state == COMPUTE) begin
                count <= count + 1'b1; // Conta os ciclos de soma/shift
            end
        end
    end

    // Bloco Combinacional: Proximo Estado e Saidas
    always_comb begin
        // Valores padrao para evitar "latches" e linhas vermelhas "X"
        next_state = state;
        load       = 1'b0;
        compute_en = 1'b0;
        done       = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                load = 1'b1; // Manda carregar os dados
                next_state = COMPUTE;
            end

            COMPUTE: begin
                compute_en = 1'b1; // Manda calcular
                if (count == 6'd31) begin // Quando fizer 32 ciclos (0 a 31), acaba
                    next_state = DONE;
                end
            end

            DONE: begin
                done = 1'b1; // Avisa o testbench que terminou!
                if (!start) begin // Só volta ao inicio quando o testbench desligar o start
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
