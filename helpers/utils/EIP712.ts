import {EIP712Domain, EIP712TypeDefinition, HardhatSignerType} from "../types/EIP712.types"

export async function signTypedData(domain: EIP712Domain, types: EIP712TypeDefinition, values: Object, signer: HardhatSignerType): Promise<string> {
    try {
      const signature = await signer._signTypedData(domain, types, values);
      return signature;  
    } catch (error) {
        console.log("[SignTypeData ERROR]", error)
        return ""
    }
}